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
        -- NB these are also hardcoded in ..\pgadmin4\pgpass.conf.
        --
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
      template {
        destination = "local/sql.d/50-quotes.sql"
        data = <<-EOD
        --
        -- database.
        --
        \connect postgres;
        create database quotes;
        revoke all on database quotes from public;
        --
        -- database definition.
        --
        \connect quotes;
        create table quote(author varchar(80) not null, text varchar(255) not null, url varchar(255) null);
        --
        -- database data.
        --
        \connect quotes;
        insert into quote(author, text, url) values('Homer Simpson', 'To alcohol! The cause of... and solution to... all of life''s problems.', 'https://en.wikipedia.org/wiki/Homer_vs._the_Eighteenth_Amendment');
        insert into quote(author, text, url) values('President Skroob, Spaceballs', 'You got to help me. I don''t know what to do. I can''t make decisions. I''m a president!', 'https://en.wikipedia.org/wiki/Spaceballs');
        insert into quote(author, text, url) values('Pravin Lal', 'Beware of he who would deny you access to information, for in his heart he dreams himself your master.', 'https://alphacentauri.gamepedia.com/Peacekeeping_Forces');
        insert into quote(author, text, url) values('Edsger W. Dijkstra', 'About the use of language: it is impossible to sharpen a pencil with a blunt axe. It is equally vain to try to do it with ten blunt axes instead.', 'https://www.cs.utexas.edu/users/EWD/transcriptions/EWD04xx/EWD498.html');
        insert into quote(author, text, url) values('Gina Sipley', 'Those hours of practice, and failure, are a necessary part of the learning process.', null);
        insert into quote(author, text, url) values('Henry Petroski', 'Engineering is achieving function while avoiding failure.', null);
        insert into quote(author, text, url) values('Jen Heemstra', 'Leadership is defined by what you do, not what you''re called.', 'https://twitter.com/jenheemstra/status/1260186699021287424');
        insert into quote(author, text, url) values('Ludwig van Beethoven', 'Don''t only practice your art, but force your way into its secrets; art deserves that, for it and knowledge can raise man to the Divine.', null);
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
