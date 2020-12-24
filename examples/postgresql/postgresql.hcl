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
        revoke all on database postgres from public;
        revoke all on database template0 from public;
        revoke all on database template1 from public;
        -- TODO restrict to create roles only?
        create role vault superuser login password 'vault';
        EOD
      }
      template {
        destination = "local/sql.d/50-grettings.sql"
        data = <<-EOD
        --
        -- database.
        --
        \connect postgres;
        create database greetings;
        revoke all privileges on database greetings from public;
        --
        -- roles.
        --
        create role "greetings-admin";
        grant all privileges on database greetings to "greetings-admin";
        create role "greetings-reader";
        grant connect on database greetings to "greetings-reader";
        --
        -- test users.
        ---
        create role "greetings-test-admin" login password 'greetings';
        grant "greetings-admin" to "greetings-test-admin";
        create role "greetings-test-reader" login password 'greetings';
        grant "greetings-reader" to "greetings-test-reader";
        --
        -- role permissions.
        --
        \connect greetings;
        grant all privileges on schema public to "greetings-admin";
        alter default privileges in schema public grant all privileges on tables to "greetings-admin";
        alter default privileges in schema public grant all privileges on sequences to "greetings-admin";
        grant usage on schema public to "greetings-reader";
        alter default privileges in schema public grant select on tables to "greetings-reader";
        --
        -- database definition.
        --
        \connect greetings;
        create table greeting(lang char(2) primary key, message varchar(128) not null);
        --
        -- database data.
        --
        \connect greetings;
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
