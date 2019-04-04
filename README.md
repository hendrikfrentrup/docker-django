# A template project for a Dockerised Django app

Why Dockerize your Django app? Well, here are three compelling reasons:
* Infrastructure-as-code
* Bring development and production environments as close together as possible ([#10 of the Twelve-Factor App](https://12factor.net/dev-prod-parity))
* Increased productivity

## Prerequisites:
* Docker & docker-compose
* Python 3.6.5 (Django 2.1)
* virtualenv & pip
* git
* A basic understanding of Django (e.g. by doing the Django tutorial)


## Setup:

We start by making a project directory (`mkdir docker-django`) and setting up a git repo (`git init`). To be honest, I usually create the repo on a remote git server (i.e. GitHub in this case) first and then clone it locally - saves some hassle setting up the remote. Then let's create and checkout a new develop branch right away (`git checkout -b develop`). The second part of the setup relates to dependency management, so we’ll create a virtual environment (`virtualenv env`) and activate it (`source env/bin/activate`) then, we’ll install Django (`pip install Django>=2.1`) Now, this will install Django locally in the virtual environment which is what we are aiming for right now. We’ll be using Django’s functionality to set up a project. But we also want to keep our dependencies in sync for other environments, so we’ll add the dependency to the requirements.txt file (`echo 'Django>=2.1' >> requirements.txt`) That deserves a first commit (`git add * && git commit -m "..."`)

The third part of the setup will be performed by Django: Let’s start a Django project (`django-admin startproject mysite`). I’m using Visual Studio Code as an editor so I’ll exclude the directory setup by it from version control (`echo ".vscode/" >> .gitignore`). We’ll do a test run of the project setup by running a local server (`python mysite/manage.py runserver`) This should allow us to check the locally running server at http://localhost:8000

Let’s finish the setup by doing another quick commit (the usual `git add ...` & `git commit ...`).

The “app” is now running locally which is often the case during development. Of course, it’s not much of an app, but let’s just forget about that for the time being. I would argue that Django’s default project already ships with enough to make it an app, such as the admin app. So I’ll just use that functionality for our journey.


## Dockerize the "app"

Now that the groundwork is laid, we can start the process of Dockerizing the app. It all starts with a Dockerfile (`touch Dockerfile`) which should look something like [this](https://github.com/hendrikfrentrup/docker-django/blob/c46deda3efc9a2b0fb6e3384f6f5807f7f7dbe26/Dockerfile)

It builds an image based on the [official Python image on Docker Hub](https://hub.docker.com/_/python/), copies our code, installs the requirements and launches the app.

We kick off the build of the image (`docker build -t django-docker:0.0.1 .`). This usually takes a while, but once it’s done, let’s go ahead and test it by running our “app” in a container (`docker run -p 8001:8001 docker-django:0.0.1`) Since the server running in the container is listening on port 8001 as opposed to 8000 compared to our “app” running locally, we are mapping port 8001 of the container to port 8001 of our local machine. Let's check that it responds on http://localhost:8001

Once the image is built and runs fine, we turn this into the first service in a new docker-compose.yml definition (`touch docker-compose.yml`, which should look like [this](https://github.com/hendrikfrentrup/docker-django/blob/eb60a4c436fe11e0a170ab74680484ae435e5f16/docker-compose.yml)). Now we can run our service simply with a quick `docker-compose up`. That’s pretty awesome and it’s basically what we want to get to, being able to launch our app with a single command. The command to run the “app” in the container needs to launch it specifying `0.0.0.0` for now. Because the container have their own network, `localhost` would refer only to the container itself. Also note that we drop the CMD from the Dockerfile and specify which command for the container to be running in docker-compose.yml.

So our “app” informs us there are unapplied migrations, namely the extra apps included in the standard Django project and the admin console is not available yet because these migrations have not been applied. As a first step, we could prepare database migrations in our local repo (`python mysite/manage.py makemigrations`). This applies to the local `db.sqlite3` in our filesystem and the admin console would now be accessible on the locally running “app” on http://localhost:8000/admin (provided the app is running).

To perform the same migration against the container, we execute the command in the container (`docker-compose exec web python mysite/manage.py migrate`) and check: http://localhost:8001/admin

Note that the container as well as the server within can be up and running and you can fire of the exec command separately. It’s basically the same as launching a new shell, logging into the container and executing the command. This is now accessible, but no admin user exists yet.
So, we’ll help that and create an admin user in the container. (`docker-compose exec web python mysite/manage.py createsuperuser`). Let’s go ahead and test that in the admin app - you should now be able to login in to the admin tool and see the admin user when you click on `Users`.

Ok great, but now we have manually changed the state of our container. If we ditch it and build one from scratch, we have to go through all of these steps again to get the container back into this state. Our efforts are directed to avoiding exactly that. In order to not lose the state, we’ll create a volume for our container so that our container and our local dev environment can have access to the same files. 

```
    volumes:
      - .:/code
```

So our local current directory is mapped to the `code` directory in the container. The local `db.sqlite3` file is excluded from version control in my case because I cloned the repo from the remote server where a `.gitignore` for Python was automatically created, which already marks these SQLite files to be excluded.

Now, if we tear down our old container (`docker-compose down`) and restart all services (`docker-compose up`), we’ll be back without the superuser. So let’s go ahead and redo the two steps above in our container (migrations and createsuperuser). We can now check both local and containerized app and they should both be in sync now, that is we should be able to login into http://localhost:8000/admin with the admin user we just set up. If we change any data here, we should see the same changes to the data in our containerised app and the database in the local file system should now be the same as the one in the Docker container. That’s pretty cool.

Eventually we want to develop an app, so let’s start an app within our project:
```
cd mysite
python manage.py startapp myapp
```


## Adding a database services

We would probably be able to get pretty far with our SQLite database since it’s possible to run enormous servers in the cloud these days, but we want to build an app that can scale horizontally and uses a fully fledged database like Postgres. So, let’s just change over to Postgres. We will do this by adding a database service, in short `db`, to our [docker-compose.yml](https://github.com/hendrikfrentrup/docker-django/blob/b0e8e186ab275fb94c3c53f267ebe2853ef3d127/docker-compose.yml). We will use the [official Postgres image from Docker Hub](https://hub.docker.com/_/postgres/). We now need tie our existing `web` service together with the `db` service.


### Environment variables in Docker

In order to connect to the database, we need to give Django the connection details and credentials by adding [Postgres service to settings.py](https://github.com/hendrikfrentrup/docker-django/blob/b0e8e186ab275fb94c3c53f267ebe2853ef3d127/mysite/mysite/settings.py). The password we define here depends on what we set up for the `db` service in the other Docker container. To keep this environment information in sync, we will use a separate environment file .env (not in source control either) which both containers have access to and store these credentials in environment variables (`touch .env`). This is a common, albeit not best practice. However, best practice around handling credentials is a completely different topic and way beyond the scope of this article.

We can also store other secrets like Django’s secret key in an .env file and other information that defines our current development environment.

In order to establish a connection to Postgres, Django depends on the Python package `psychopg2`, so we will add this dependency to our [requirements file](https://github.com/hendrikfrentrup/docker-django/blob/b0e8e186ab275fb94c3c53f267ebe2853ef3d127/requirements.txt) as well as additional dependencies to [our Dockerfile](https://github.com/hendrikfrentrup/docker-django/blob/b0e8e186ab275fb94c3c53f267ebe2853ef3d127/Dockerfile), which means a rebuild of our image will be necessary.

For reference, it may be easier to take a look at the commit [here](https://github.com/hendrikfrentrup/docker-django/commit/b0e8e186ab275fb94c3c53f267ebe2853ef3d127).

That's really it though, we should be able to launch all services with `docker-compose up` again. That was actually pretty easy, wasn’t it? Now we can toy around with a Postgres database.


### Data Migrations to automatically set up a superuser

We can manually run migrations again against the database service and then test our app and see if everything is working fine.
```
docker-compose exec web python mysite/manage.py migrate
docker-compose exec web python mysite/manage.py createsuperuser
```

At this point, we are getting tired of running migrations and especially creating a superuser all over as it requires so much typed input. But we don’t want to be doing this every time we spin up our app. Also, the credentials for the superuser should be kept as safe as the other credentials and not hardcoded somewhere in the repo or passed in as command-line arguments, which usually end up in our bash history.
To mitigate this, let’s make use of a data migration to create a superuser. That way the creation of the superuser is just another migration to be applied.
```
python mysite/manage.py makemigrations --empty myapp
```
This will create an empty migration, which we can change to [this migration](https://github.com/hendrikfrentrup/docker-django/blob/d48f24ab6b7723f28a93dfa2848859e53a45a486/mysite/myapp/migrations/0001_initial.py). All environment variables used in this migration need to also be specified in our docker-compose.yml as well as the .env file, but once they are everything is kept in sync.

This brings us to a contentious issue: Should migrations be automatically applied when spinning up a container? Some people prefer it that way, which allows them to spin up there app with a single command. However, I think they should not be done automatically because it could lead to problems in production. For example, the web app is launched in a new container and unintentionally applies migrations against a production database. Also, what if we launch multiple containers of the app? They would kick off migrations concurrently. Sounds like trouble to me. I would prefer this step to remain manual and rather make it easier to apply them quickly by defining a shell alias.


### Getting a better overview of our `db` service with pgadmin

For development purposes, we want to be able to see our Postgres schema and probe the data. Now instead of installing a Postgres client or using our IDE to do this, we will leverage the power of containers to deploy an admin tool. In fact, our `db` service at the moment does not have any mapped ports to our local machine, so we actually wouldn’t be able to connect to it with a local JDBC client. So, let's instead add a pgadmin service to our docker-compose.yml. I didn't find an official image, but there is a public one [here](https://hub.docker.com/r/dpage/pgadmin4/). Since this is just an auxiliary image, we'll choose to trust it. For stuff in production, we might not want to do that. So, the docker-compose.yml would change in [this way](https://github.com/hendrikfrentrup/docker-django/commit/f338542c672f5c7db1842b956d7ce955e003e893). Again, make sure the necessary environment variables are also specified in .env. Now it's time to start up all services again and check out our admin tool for Postgres at http://localhost:8080.

With the credentials from the environment variables, we should be able to login. To establish a connection to our database, let's click on "Add server". This opens a model where "Name" can be anything we want, say “Test”, then let's click on the tab “Connection” and fill in `db` as hostname, and our database credentials defined in the .env file for username and password, so for examples `postgres` and `secret`. Once a connection is established to the db - it will prompt if this did not succeed - we can browse the schema and look at some sample data in the database. Happy days for DB admins! Now, just as a matter of convenience, let’s also expose the port `5432` of our container so that our IDE can show us the schema by tapping into localhost.

At this point we already have a pretty neat development environment.