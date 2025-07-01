# Keycloak provider for user federation from OBP via PostgreSQL

This project connects OBP's PostgreSQL database as a user federation provider to Keycloak.

## Requirements

The following software is required to work build it locally:

* [Git](https://git-scm.com) 2.2.1 or later
* [Docker Engine](https://docs.docker.com/engine/install/) or [Docker Desktop](https://docs.docker.com/desktop/) 1.9 or later
* [Maven](https://maven.apache.org/) 3.8.5 or later
* [Java](https://www.java.com/ru/) 17 or later

See the links above for installation instructions on your platform. You can verify the versions are installed and running:

    $ git --version
    $ curl -V
    $ mvn -version
    $ docker --version
    $ java --version

## Usage
### Docker containers
[Postgres](https://www.postgresql.org/) - database for which we want to store User Federation.

[Keycloak](https://www.keycloak.org/) - KC container with custom certificate, for use over `https`. The container is described in [Dockerfile](/docker/Dockerfile).

### Build SPI provider

Before you build the SPI provider you must add the information about the database. 
This information is specified in the file [persistence.xml](/src/main/resources/META-INF/persistence.xml#L15)

> :warning: **Replace the URI** `jdbc:postgresql://localhost:5432/keycloak` **with your database address.**

### Using Postgres
Connect to an existing OBP PostgreSQL database. For development/testing purposes, create your own database instance locally:

To deploy the container use the script :
```shell
$ sh/pg.sh
```

The script deploys the container locally. 

It uses port : 5432. 

The scripts in the container create a `keycloak` database. 
In the database create a table `authuser` :
```sql
CREATE TABLE public.authuser (
	id bigserial NOT NULL,
	firstname varchar(100) NULL,
	lastname varchar(100) NULL,
	email varchar(100) NULL,
	username varchar(100) NULL,
	password_pw varchar(48) NULL,
	password_slt varchar(20) NULL,
	provider varchar(100) NULL,
	locale varchar(16) NULL,
	validated bool NULL,
	user_c int8 NULL,
	uniqueid varchar(32) NULL,
	createdat timestamp NULL,
	updatedat timestamp NULL,
	timezone varchar(32) NULL,
	superuser bool NULL,
	passwordshouldbechanged bool NULL,
	CONSTRAINT authuser_pk PRIMARY KEY (id)
);
```
Add mock user to the table.

### Using Keycloak

KC is deployed in a custom container.

To deploy the KC container, I created a [Dockerfile](/docker/Dockerfile) file in which :
- I create a certificate for `https` access
- I add a provider `kc-obp-provider`

## Build the project

Run the script :
```shell
$ sh/run.sh
```
This script will build the SPI provider. 

Deploys the KC container, adds the SPI provider and restarts the container to apply the changes. 

## Login to KC

After launching, go to [https://localhost:8443](https://localhost:8443) in your browser.
To log in to KC, use admin credentials :
```properties
user : admin
pass : admin
```

Click the [User federation](https://localhost:8443/admin/master/console/#/master/user-federation) tab .

The provider ``kc-obp-provider`` is in list of providers.

![KC providers](/docs/images/providers.png?raw=true "KC providers")

