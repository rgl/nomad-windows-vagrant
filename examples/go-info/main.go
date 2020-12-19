package main

import (
	"flag"
	"fmt"
	"html/template"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
)

var indexTemplate = template.Must(template.New("Index").Parse(`<!DOCTYPE html>
<html>
<head>
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
