# bl :unamused:

a blog

## About

Just a simple blog platform, focused on the content.

###### In development

## Installation

```shell
# Clone code
$ git clone https://github.com/oltdaniel/bl && cd bl
# Start postgres container
$ docker run --name bl-postgres --rm -e POSTGRES_PASSWORD=bacon -v `pwd`/pgdata:/var/lib/postgresql/data -p 5432:5432 postgres:alpine
# Create postgres database
$ docker run -it --rm --link bl-postgres:psql postgres:alpine psql -h $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' bl-postgres) -U postgres
# ...
postgres=# CREATE DATABASE bl WITH OWNER "postgres" ENCODING 'UTF8';
postgres=# \quit
# Generate two new secrets
$ ruby -e "require 'securerandom'; 2.times { puts SecureRandom.hex 64 }"
# Insert secrets into `bl.yml`
# NOTICE: Update postgres settings if required
$ vim bl.yml
# Install dependencies
$ bundle
# Create first user
$ ./scripts/add-user
# Start bl
$ ./bin/bl
```

**Requirements**:
- `docker` (see [here](https://docs.docker.com/install/))
- `ruby` (`rvm` suggested, see [here](https://rvm.io/))

## License

_Just do what you'd like to_

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/oltdaniel/bl/blob/master/LICENSE)

#### Credit

[Daniel Oltmanns](https://github.com/oltdaniel) - creator
