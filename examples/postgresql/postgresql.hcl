# see https://www.nomadproject.io/docs/job-specification

job "postgresql" {
  datacenters = ["dc1"]
  group "postgresql" {
    task "postgresql" {
      driver = "docker"
      template {
        destination = "local/sql.d/00-init.sql"
        data = <<-EOD
        \connect postgres;
        -- TODO restrict to create roles only?
        create role vault superuser login password 'vault';
        EOD
      }
      template {
        destination = "local/sql.d/50-grettings.sql"
        data = <<-EOD
        create database greetings;
        \connect greetings;
        create table greeting(lang char(2) primary key, message varchar(128) not null);
        insert into greeting(lang, message) values('pt', 'Olá Mundo');
        insert into greeting(lang, message) values('es', 'Hola Mundo');
        insert into greeting(lang, message) values('fr', 'Bonjour le Monde');
        insert into greeting(lang, message) values('it', 'Ciao Mondo');
        insert into greeting(lang, message) values('en', 'Hello World');
        EOD
      }
      config {
        image = "postgresql:13.1"
        port_map {
          postgresql = 5432
        }
      }
      resources {
        network {
          port "postgresql" {
            # NB this is non-ideal. but vault/libpq does not support srv
            #    records, so have to use a host/static port here.
            static = 5432
          }
        }
      }
      service {
        name = "postgresql"
        port = "postgresql"
        tags = ["postgresql"]
        check {
          type = "script"
          command = "c:/pgsql/bin/psql.exe"
          args = ["-v", "ON_ERROR_STOP=1", "-w", "-t", "-U", "postgres", "-c", "select 1", "postgres"]
          interval = "20s"
          timeout = "2s"
        }
      }
    }
  }
}
