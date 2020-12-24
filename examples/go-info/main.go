package main

import (
	"database/sql"
	"flag"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"net/url"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/lib/pq"
	"github.com/olekukonko/tablewriter"

	vault "github.com/hashicorp/vault/api"
	_ "github.com/lib/pq"
)

var indexTemplate = template.Must(template.New("Index").Parse(`<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8" />
<title>go-info</title>
<style>
body {
	font-family: monospace;
	color: #555;
	background: #e6edf4;
	padding: 1.25rem;
	margin: 0;
}
table {
	background: #fff;
	border: .0625rem solid #c4cdda;
	border-radius: 0 0 .25rem .25rem;
	border-spacing: 0;
	margin-bottom: 1.25rem;
	padding: .75rem 1.25rem;
	text-align: left;
	white-space: pre;
}
table > caption {
	background: #f1f6fb;
	text-align: left;
	font-weight: bold;
	padding: .75rem 1.25rem;
	border: .0625rem solid #c4cdda;
	border-radius: .25rem .25rem 0 0;
	border-bottom: 0;
}
table td, table th {
	padding: .25rem;
}
table > tbody > tr:hover {
	background: #f1f6fb;
}
</style>
</head>
<body>
	<table>
		<caption>Properties</caption>
		<tbody>
			<tr><th>Pid</th><td>{{.Pid}}</td></tr>
			<tr><th>Request</th><td>{{.Request}}</td></tr>
			<tr><th>Client Address</th><td>{{.ClientAddress}}</td></tr>
			<tr><th>Server Address</th><td>{{.ServerAddress}}</td></tr>
			<tr><th>Hostname</th><td>{{.Hostname}}</td></tr>
			<tr><th>Current Directory</th><td>{{.CurrentDirectory}}</td></tr>
			<tr><th>Os</th><td>{{.Os}}</td></tr>
			<tr><th>Architecture</th><td>{{.Architecture}}</td></tr>
			<tr><th>Runtime</th><td>{{.Runtime}}</td></tr>
		</tbody>
	</table>
	<table>
		<caption>Environment Variables</caption>
		<tbody>
			{{- range .Environment}}
			<tr>
				<th>{{.Name}}</th>
				<td>{{.Value}}</td>
			</tr>
			{{- end}}
		</tbody>
	</table>
	<table>
		<caption>Secrets</caption>
		<tbody>
			{{- range .Secrets}}
			<tr>
				<th>{{.Name}}</th>
				<td>{{.Value}}</td>
			</tr>
			{{- end}}
		</tbody>
	</table>
	<table>
		<caption>Vault</caption>
		<tbody>
			{{- range .Vault}}
			<tr>
				<th>{{.Name}}</th>
				<td>{{.Value}}</td>
			</tr>
			{{- end}}
		</tbody>
	</table>
	<table>
		<caption>PostgreSQL with Vault managed user</caption>
		<tbody>
			{{- range .VaultPostgreSQL}}
			<tr>
				<th>{{.Name}}</th>
				<td>{{.Value}}</td>
			</tr>
			{{- end}}
		</tbody>
	</table>
	<table>
		<caption>PostgreSQL</caption>
		<tbody>
			{{- range .PostgreSQL}}
			<tr>
				<th>{{.Name}}</th>
				<td>{{.Value}}</td>
			</tr>
			{{- end}}
		</tbody>
	</table>
</body>
</html>
`))

type nameValuePair struct {
	Name  string
	Value string
}

type indexData struct {
	Pid              int
	CurrentDirectory string
	Request          string
	ClientAddress    string
	ServerAddress    string
	Hostname         string
	Os               string
	Architecture     string
	Runtime          string
	Environment      []nameValuePair
	Secrets          []nameValuePair
	Vault            []nameValuePair
	VaultPostgreSQL  []nameValuePair
	PostgreSQL       []nameValuePair
}

type nameValuePairs []nameValuePair

func (a nameValuePairs) Len() int      { return len(a) }
func (a nameValuePairs) Swap(i, j int) { a[i], a[j] = a[j], a[i] }
func (a nameValuePairs) Less(i, j int) bool {
	if a[i].Name < a[j].Name {
		return true
	}
	if a[i].Name > a[j].Name {
		return false
	}
	return a[i].Value < a[j].Value
}

func getVault() []nameValuePair {
	if os.Getenv("VAULT_TOKEN") == "" {
		return nil
	}
	client, err := vault.NewClient(nil)
	if err != nil {
		return []nameValuePair{{Name: "ERROR", Value: fmt.Sprintf("Failed to create client: %v", err)}}
	}

	sys := client.Sys()

	result := []nameValuePair{}

	health, err := sys.Health()
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR Health", Value: fmt.Sprintf("Failed to get health status: %v", err)})
	} else {
		result = append(result,
			nameValuePair{Name: "ClusterID", Value: health.ClusterID},
			nameValuePair{Name: "ClusterName", Value: health.ClusterName},
			nameValuePair{Name: "Sealed", Value: strconv.FormatBool(health.Sealed)},
			nameValuePair{Name: "Version", Value: health.Version},
		)
	}

	tokenInformation, err := client.Auth().Token().LookupSelf()
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR Token LookupSelf", Value: fmt.Sprintf("Failed to lookup self token: %v", err)})
	} else {
		tokenMetadata, err := tokenInformation.TokenMetadata()
		if err != nil {
			result = append(result, nameValuePair{Name: "ERROR Token Metadata", Value: fmt.Sprintf("Failed to get token metadata: %v", err)})
		} else {
			metadata := make([]nameValuePair, 0)
			for k, v := range tokenMetadata {
				metadata = append(metadata,
					nameValuePair{Name: "Token Metadata", Value: fmt.Sprintf("%s=%s", k, v)},
				)
			}
			sort.Sort(nameValuePairs(metadata))
			result = append(result, metadata...)
		}
		// NB tokenPolicies = TokenPolicies + IdentityPolicies
		tokenPolicies, err := tokenInformation.TokenPolicies()
		if err != nil {
			result = append(result, nameValuePair{Name: "ERROR Token Policies", Value: fmt.Sprintf("Failed to get token policies: %v", err)})
		} else {
			result = append(result,
				nameValuePair{Name: "Token Policies", Value: strings.Join(tokenPolicies, "\n")},
			)
		}
		if err != nil {
			result = append(result, nameValuePair{Name: "ERROR Token TokenPolicies", Value: fmt.Sprintf("Failed to get token token policies: %v", err)})
		} else {
			result = append(result,
				nameValuePair{Name: "Token Token Policies", Value: strings.Join(tokenInformation.Auth.TokenPolicies, "\n")},
			)
		}
		if err != nil {
			result = append(result, nameValuePair{Name: "ERROR Token IdentityPolicies", Value: fmt.Sprintf("Failed to get token identity policies: %v", err)})
		} else {
			result = append(result,
				nameValuePair{Name: "Token Identity Policies", Value: strings.Join(tokenInformation.Auth.IdentityPolicies, "\n")},
			)
		}
	}

	return result
}

func sqlExecuteScalar(dataSourceName string, sqlStatement string) (string, error) {
	db, err := sql.Open("postgres", dataSourceName)
	if err != nil {
		return "", fmt.Errorf("Open connection failed: %w", err)
	}
	defer db.Close()

	err = db.Ping()
	if err != nil {
		return "", fmt.Errorf("Ping failed: %w", err)
	}

	var scalar string

	err = db.QueryRow(sqlStatement).Scan(&scalar)
	if err != nil {
		return "", fmt.Errorf("Scan failed: %w", err)
	}

	return scalar, nil
}

func sqlGetUsers(dataSourceName string) (string, error) {
	db, err := sql.Open("postgres", dataSourceName)
	if err != nil {
		return "", fmt.Errorf("Open connection failed: %w", err)
	}
	defer db.Close()

	// see https://www.postgresql.org/docs/13/view-pg-user.html
	var sqlStatement = `
select
	usename,
	usecreatedb,
	usesuper,
	userepl,
	usebypassrls,
	valuntil,
	array(
		select
			b.rolname
		from
			pg_catalog.pg_auth_members m
				inner join
			pg_catalog.pg_roles b
				on m.roleid = b.oid
		where
			m.member = usesysid
	) as memberof
from pg_catalog.pg_user
order by usename desc
`

	rows, err := db.Query(sqlStatement)
	if err != nil {
		return "", fmt.Errorf("Query failed: %w", err)
	}
	defer rows.Close()

	var tableBuilder strings.Builder
	table := tablewriter.NewWriter(&tableBuilder)
	table.SetHeader([]string{"Name", "Privileges", "Member Of", "Valid Until"})
	for rows.Next() {
		var username string
		var usecreatedb bool
		var usesuper bool
		var userepl bool
		var usebypassrls bool
		var valuntil sql.NullTime
		var memberof []string
		err := rows.Scan(&username, &usecreatedb, &usesuper, &userepl, &usebypassrls, &valuntil, pq.Array(&memberof))
		if err != nil {
			return "", fmt.Errorf("Scan failed: %w", err)
		}
		attributes := make([]string, 0)
		if usecreatedb {
			attributes = append(attributes, "create db")
		}
		if usesuper {
			attributes = append(attributes, "super user")
		}
		if userepl {
			attributes = append(attributes, "streaming replication")
		}
		if usebypassrls {
			attributes = append(attributes, "bypass row level security policy")
		}
		var expirationTime string
		if valuntil.Valid {
			expirationTime = valuntil.Time.Local().Format(time.RFC1123Z)
		}
		table.Append([]string{username, strings.Join(attributes, ", "), strings.Join(memberof, ", "), expirationTime})
	}
	table.Render()

	err = rows.Err()
	if err != nil {
		return "", fmt.Errorf("Query failed: %w", err)
	}

	return tableBuilder.String(), nil
}

func sqlGetDatabaseUserPrivileges(dataSourceName string) (string, error) {
	db, err := sql.Open("postgres", dataSourceName)
	if err != nil {
		return "", fmt.Errorf("Open connection failed: %w", err)
	}
	defer db.Close()

	// see https://www.postgresql.org/docs/13/view-pg-database.html
	// see https://www.postgresql.org/docs/13/view-pg-user.html
	var sqlStatement = `
select
	d.datname as database,
	u.usename as user,
	has_database_privilege(u.usesysid, d.oid, 'CREATE') as db_create_privilege,
	has_database_privilege(u.usesysid, d.oid, 'CONNECT') as db_connect_privilege,
	has_database_privilege(u.usesysid, d.oid, 'TEMPORARY') as db_temporary_privilege
from
	pg_user as u
	cross join
	pg_database as d
where
	u.valuntil is not null
	and
	d.datname not like 'template%'
order by
	d.datname,
	u.usename
`

	rows, err := db.Query(sqlStatement)
	if err != nil {
		return "", fmt.Errorf("Query failed: %w", err)
	}
	defer rows.Close()

	var tableBuilder strings.Builder
	table := tablewriter.NewWriter(&tableBuilder)
	table.SetHeader([]string{"Database", "User", "Privileges"})
	for rows.Next() {
		var database string
		var user string
		var dbCreatePrivilege bool
		var dbConnectPrivilege bool
		var dbTemporaryPrivilege bool
		err := rows.Scan(&database, &user, &dbCreatePrivilege, &dbConnectPrivilege, &dbTemporaryPrivilege)
		if err != nil {
			return "", fmt.Errorf("Scan failed: %w", err)
		}
		privileges := make([]string, 0)
		if dbCreatePrivilege {
			privileges = append(privileges, "CREATE")
		}
		if dbConnectPrivilege {
			privileges = append(privileges, "CONNECT")
		}
		if dbTemporaryPrivilege {
			privileges = append(privileges, "TEMPORARY")
		}
		table.Append([]string{database, user, strings.Join(privileges, ", ")})
	}
	table.Render()

	err = rows.Err()
	if err != nil {
		return "", fmt.Errorf("Query failed: %w", err)
	}

	return tableBuilder.String(), nil
}

func getVaultPostgreSQL() []nameValuePair {
	postgresqlAddr := os.Getenv("POSTGRESQL_ADDR")
	if postgresqlAddr == "" {
		return nil
	}
	if os.Getenv("VAULT_TOKEN") == "" {
		return nil
	}
	client, err := vault.NewClient(nil)
	if err != nil {
		return []nameValuePair{{Name: "ERROR", Value: fmt.Sprintf("Failed to create vault client: %v", err)}}
	}
	// TODO cache the `creds` object up to the lease duration and renew it when
	//      needed. maybe there's even an existing library for this.
	creds, err := client.Logical().Read("database/creds/greetings-reader")
	if err != nil {
		return []nameValuePair{{Name: "ERROR", Value: fmt.Sprintf("Failed to get database/creds/greetings-reader: %v", err)}}
	}
	// TODO renew lease OR the code that obtains a database connection should do that when needed.
	username := creds.Data["username"].(string)
	password := creds.Data["password"].(string)

	dataSourceNameURL, err := url.Parse(postgresqlAddr)
	if err != nil {
		return []nameValuePair{{Name: "ERROR", Value: fmt.Sprintf("Failed to parse POSTGRESQL_ADDR: %v", err)}}
	}
	dataSourceNameURL.User = url.UserPassword(username, password)
	dataSourceName := dataSourceNameURL.String()

	result := []nameValuePair{}

	result = append(result, nameValuePair{Name: "Vault Secret LeaseID", Value: creds.LeaseID})

	leaseDuration := time.Duration(creds.LeaseDuration * int(time.Second))
	leaseExpirationTime := time.Now().Add(leaseDuration)
	result = append(result, nameValuePair{Name: "Vault Secret LeaseDuration", Value: fmt.Sprintf("%s (until %s)", leaseDuration.String(), leaseExpirationTime.Local().Format(time.RFC1123Z))})

	version, err := sqlExecuteScalar(dataSourceName, "select version()")
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR Version", Value: fmt.Sprintf("Failed to get version: %v", err)})
	} else {
		result = append(result, nameValuePair{Name: "Version", Value: version})
	}

	user, err := sqlExecuteScalar(dataSourceName, "select current_user")
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR User", Value: fmt.Sprintf("Failed to get user: %v", err)})
	} else {
		result = append(result, nameValuePair{Name: "User", Value: user})
	}

	greeting, err := sqlExecuteScalar(dataSourceName, "select message from greeting order by random() limit 1")
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR Greeting", Value: fmt.Sprintf("Failed to get greeting: %v", err)})
	} else {
		result = append(result, nameValuePair{Name: "Greeting", Value: greeting})
	}

	return result
}

func getPostgreSQL() []nameValuePair {
	postgresqlAddr := os.Getenv("POSTGRESQL_ADDR")
	if postgresqlAddr == "" {
		return nil
	}
	username := "postgres"
	password := "postgres"
	dataSourceNameURL, err := url.Parse(postgresqlAddr)
	if err != nil {
		return []nameValuePair{{Name: "ERROR", Value: fmt.Sprintf("Failed to parse POSTGRESQL_ADDR: %v", err)}}
	}
	dataSourceNameURL.User = url.UserPassword(username, password)
	dataSourceName := dataSourceNameURL.String()

	result := []nameValuePair{}

	version, err := sqlExecuteScalar(dataSourceName, "select version()")
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR Version", Value: fmt.Sprintf("Failed to get version: %v", err)})
	} else {
		result = append(result, nameValuePair{Name: "Version", Value: version})
	}

	user, err := sqlExecuteScalar(dataSourceName, "select current_user")
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR User", Value: fmt.Sprintf("Failed to get user: %v", err)})
	} else {
		result = append(result, nameValuePair{Name: "User", Value: user})
	}

	users, err := sqlGetUsers(dataSourceName)
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR Users", Value: fmt.Sprintf("Failed to get users: %v", err)})
	} else {
		result = append(result, nameValuePair{Name: "Users", Value: users})
	}

	databaseUserPrivileges, err := sqlGetDatabaseUserPrivileges(dataSourceName)
	if err != nil {
		result = append(result, nameValuePair{Name: "ERROR Privileges", Value: fmt.Sprintf("Failed to get databases user privileges: %v", err)})
	} else {
		result = append(result, nameValuePair{Name: "Privileges", Value: databaseUserPrivileges})
	}

	return result
}

func main() {
	log.SetFlags(0)

	var listenAddress = flag.String("listen", ":8000", "Listen address.")

	flag.Parse()

	if flag.NArg() != 0 {
		flag.Usage()
		log.Fatalf("\nERROR You MUST NOT pass any positional arguments")
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Printf("%s %s%s\n", r.Method, r.Host, r.URL)

		if r.URL.Path != "/" {
			http.Error(w, "Not Found", http.StatusNotFound)
			return
		}

		hostname, err := os.Hostname()
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "text/html")

		environment := make([]nameValuePair, 0)
		for _, v := range os.Environ() {
			parts := strings.SplitN(v, "=", 2)
			name := strings.ToUpper(parts[0])
			value := parts[1]
			switch name {
			case "PATH":
				fallthrough
			case "PATHEXT":
				fallthrough
			case "XDG_DATA_DIRS":
				fallthrough
			case "XDG_CONFIG_DIRS":
				value = strings.Join(
					strings.Split(value, string(os.PathListSeparator)),
					"\n")
			}
			environment = append(environment, nameValuePair{name, value})
		}
		sort.Sort(nameValuePairs(environment))

		secrets := make([]nameValuePair, 0)
		secretFiles, _ := filepath.Glob(path.Join(os.Getenv("NOMAD_SECRETS_DIR"), "*"))
		for _, v := range secretFiles {
			name := filepath.Base(v)
			value, _ := ioutil.ReadFile(v)
			secrets = append(secrets, nameValuePair{name, string(value)})
		}
		sort.Sort(nameValuePairs(secrets))

		currentDirectory, _ := os.Getwd()

		err = indexTemplate.ExecuteTemplate(w, "Index", indexData{
			Pid:              os.Getpid(),
			CurrentDirectory: currentDirectory,
			Request:          fmt.Sprintf("%s %s%s", r.Method, r.Host, r.URL),
			ClientAddress:    r.RemoteAddr,
			ServerAddress:    r.Context().Value(http.LocalAddrContextKey).(net.Addr).String(),
			Hostname:         hostname,
			Os:               runtime.GOOS,
			Architecture:     runtime.GOARCH,
			Runtime:          runtime.Version(),
			Environment:      environment,
			Secrets:          secrets,
			Vault:            getVault(),
			VaultPostgreSQL:  getVaultPostgreSQL(),
			PostgreSQL:       getPostgreSQL(),
		})
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	})

	fmt.Printf(
		"Listening at http://%s (mapped to host port %s)\n",
		*listenAddress,
		os.Getenv("NOMAD_HOST_PORT_http"))

	err := http.ListenAndServe(*listenAddress, nil)
	if err != nil {
		log.Fatalf("Failed to ListenAndServe: %v", err)
	}
}
