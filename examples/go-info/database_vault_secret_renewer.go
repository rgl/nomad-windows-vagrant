package main

import (
	"fmt"
	"log"
	"net/url"
	"os"
	"sync"
	"time"

	vault "github.com/hashicorp/vault/api"
)

type DatabaseVaultSecret struct {
	DataSourceName      string
	LeaseID             string
	LeaseTime           time.Time
	LeaseExpirationTime time.Time
}

type DatabaseVaultSecretRenewer struct {
	l               sync.Mutex
	client          *vault.Client
	credentialsPath string
	dataSourceName  *url.URL
	secretCh        chan chan *DatabaseVaultSecret
	stopped         bool
	stopCh          chan struct{}
}

func NewDatabaseVaultSecretRenewer(credentialsPath string, databaseSourceNameEnv string) (*DatabaseVaultSecretRenewer, error) {
	dataSourceName := os.Getenv(databaseSourceNameEnv)
	if dataSourceName == "" {
		return nil, fmt.Errorf("No %s environment variable", databaseSourceNameEnv)
	}
	dataSource, err := url.Parse(dataSourceName)
	if err != nil {
		return nil, fmt.Errorf("Failed to parse %s: %v", databaseSourceNameEnv, err)
	}
	if os.Getenv("VAULT_TOKEN") == "" {
		return nil, fmt.Errorf("No VAULT_TOKEN environment variable")
	}
	client, err := vault.NewClient(nil)
	if err != nil {
		return nil, fmt.Errorf("Failed to create vault client: %v", err)
	}
	return &DatabaseVaultSecretRenewer{
		client:          client,
		credentialsPath: credentialsPath,
		dataSourceName:  dataSource,
		secretCh:        make(chan chan *DatabaseVaultSecret, 1),
		stopped:         true,
		stopCh:          make(chan struct{}),
	}, nil
}

func (r *DatabaseVaultSecretRenewer) Renew() {
	var renewer *vault.Renewer

	for {
		if renewer != nil {
			renewer.Stop()
			renewer = nil
		}

		select {
		case <-r.stopCh:
			return
		default:
		}

		log.Printf("Reading the vault %s secret", r.credentialsPath)
		secret, err := r.client.Logical().Read(r.credentialsPath)
		if err != nil {
			log.Printf("Failed to read the %s secret: %v", r.credentialsPath, err)
			time.Sleep(5 * time.Second) // TODO exponential backoff?
			continue
		}

		leaseTime := time.Now()
		leaseExpirationTime := leaseTime.Add(time.Duration(secret.LeaseDuration * int(time.Second)))
		log.Printf("Database %s secret created. LeaseID %s (valid until %s)", r.credentialsPath, secret.LeaseID, leaseExpirationTime)

		renewer, err = r.client.NewRenewer(&vault.RenewerInput{Secret: secret})
		if err != nil {
			log.Printf("Failed to create renewer to the %s secret: %v", r.credentialsPath, err)
			time.Sleep(5 * time.Second) // TODO exponential backoff?
			continue
		}
		go renewer.Renew()

		username := secret.Data["username"].(string)
		password := secret.Data["password"].(string)

		r.dataSourceName.User = url.UserPassword(username, password)

		dataSourceName := r.dataSourceName.String()

	renewSecret:
		for {
			select {
			case <-r.stopCh:
				return
			case ch := <-r.secretCh:
				ch <- &DatabaseVaultSecret{
					DataSourceName:      dataSourceName,
					LeaseID:             secret.LeaseID,
					LeaseTime:           leaseTime,
					LeaseExpirationTime: leaseExpirationTime,
				}
			case err := <-renewer.DoneCh():
				if err != nil {
					log.Printf("Database %s secret renew failed: %v", r.credentialsPath, err)
					break renewSecret
				}
				// NB postgreSQLVaultSecret could still be used a little
				//    bit more (until the expiration date); but its
				//    safer/easier to create a new secret.
				//    TODO it seems the new vault client (after 1.0.4) has
				//    improvements over the current one, so, revise this
				//    when that comes out.
				// see https://github.com/hashicorp/vault/issues/10490
				log.Printf("Database %s secret MaxTTL reached.", r.credentialsPath)
				break renewSecret
			case renewal := <-renewer.RenewCh():
				leaseTime = renewal.RenewedAt
				leaseExpirationTime = leaseTime.Add(time.Duration(renewal.Secret.LeaseDuration * int(time.Second)))
				log.Printf("Database %s secret renewed. LeaseID %s (valid until %s)", r.credentialsPath, renewal.Secret.LeaseID, leaseExpirationTime)
			}
		}
	}
}

func (r *DatabaseVaultSecretRenewer) GetSecret() *DatabaseVaultSecret {
	replyCh := make(chan *DatabaseVaultSecret, 1)
	r.secretCh <- replyCh
	return <-replyCh
}

func (r *DatabaseVaultSecretRenewer) Stop() {
	r.l.Lock()
	defer r.l.Unlock()
	if !r.stopped {
		close(r.stopCh)
		r.stopped = true
	}
}
