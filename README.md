# A template project for a Dockerised Django app

## Presentations

A state of this project was presented at Docker Auckland:
https://www.slideshare.net/frentrup/dockerize-a-django-app-elegantly

## Articles

In detail, the articles describe the development process:

Number 1: Setup and admin tasks
https://medium.com/devopslinks/tech-edition-how-to-dockerize-a-django-web-app-elegantly-924c0b83575d

Number 2: Local debugging, proxy and logging
https://medium.com/devopslinks/tech-edition-django-dockerization-with-bells-and-whistles-and-a-tad-bit-of-cleverness-2b5d1b57e289

## Motivation

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

### Decouple

Earlier, I alluded to this great situation of having our database running in a container and having the app running locally. However, we have set up our system for the app to run in a container and running a local app doesn’t work at the moment.
So, what if I want to debug the web app? It’s hard to debug inside containers. It’s definitely worth being able to run a local app with other containerized services alongside. It’s even possible to run a local app and a containerized app side by side and this can be quite useful in development to test for side effects. After all, we want to build scalable apps and here scaling is part of the development environment

So, why doesn’t it work? For one, the containers are spun up with all the environment variables in `.env` specified, which we don’t have available locally. Moreover, our locally running app doesn’t recognize the `db` host specified in our Django settings, because the containerized database is mapped to a port on localhost.

We therefore make a few small changes to our `settings.py` file so that all local app and containers to run side by side. We’ll use a useful python package called [decouple](https://pypi.org/project/python-decouple/). Let’s also remember to add that to our requirements!

```
from decouple import configSECRET_KEY = config(‘DJANGO_SECRET_KEY’)
…
DB_HOST = config('DJANGO_DB_HOST', default='localhost')
POSTGRES_USER = config('POSTGRES_USER')
POSTGRES_PASSWORD = config('POSTGRES_PASSWORD')
…
```

The decouple module is a bit more sophisticated than getting our config directly from environment variables (`POSTGRES_PASSWORD = os.environ.get(‘POSTGRES_PASSWORD’)`). It also applied a useful and commonly used hierarchy to obtaining config: First, look for an environment variable, otherwise check for a `.env` file in the project root, otherwise go for the default. It also throws useful exceptions such as

```
decouple.UndefinedValueError: MISSING_CONFIG not found. Declare it as envvar or define a default value.
```

So, our locally running app will try to locate the `.env` file and read optional parameters from there, but only if the environment settings are not set. Let’s notice the fallback option for the `DB_HOST` is `localhost` as this is not specified in the `.env` file, instead we specify this in our `docker-compose.yml` file under the web service:

```
environment:
 DJANGO_DB_HOST: "db"
 ```

 The db setting change to this:

```
 DATABASES = {
 ‘default’: {
 ‘ENGINE’: ‘django.db.backends.postgresql’,
 ‘NAME’: ‘postgres’, 
 ‘USER’: POSTGRES_USER,
 ‘PASSWORD’: POSTGRES_PASSWORD,
 ‘HOST’: DB_HOST,
 ‘PORT’: ‘5432’, 
 },
```

 We will add the `DJANGO_DEBUG=True` to our `.env` file. Now, we just have to catch up with our container in our local environment and add the required Python Postgres module to our local virtual environment (`pip install psycopg2-binary`).

If we wanted run migrate from our local machine and make the changes against the containerized database, then we would have to follow a similar approach for our migration, but it is better practice to run migrations from a container anyway.

### Moving to a proper web server and employing a proxy server

So, we are still running Django’s development server inside our container. In the spirit of moving closer to a production environment, we’ll switch to a proper web server and since all the cool kids are using nginx these days, so will we. Peer pressure, what could go wrong? There is also an official repository of [nginx](https://hub.docker.com/_/nginx/). Thank you, peers! Let’s go ahead and add that as a service:

```
nginx:
 image: nginx:latest
 ports:
  — 8088:80
```

We are mapping nginx’s port 80 to our `localhost` port 8088. We don’t worry about running out of ports as we have another 60000+ available (2¹⁶ to be precise).

Let’s check if it’s running by visiting [`http://localhost:8088`](http://localhost:8088). Yep, looks good. Also, we can note the nginx logline in the terminal where we’ve spun up our containers:

```
nginx_1 | 192.168.0.1 — — [05/Dec/2018:10:18:31 +0000] “GET / HTTP/1.1” 304 0 “-” “<some User-Agent stuff>” “-”
```

So this nginx proxy server will help us handle requests and serving static files, but first we need to configure nginx by adding a config file:
````
mkdir nginx
touch nginx/default.conf
````

A really dead simple configuration would look something like this:

```
server {
 listen 80;
 server_name localhost;location / {
 proxy_pass http://web:8001;
 }
}
````

So, we telling nginx to listen on port 80 and we forwarding requests to `/` on this port to our web service on port 8001. At the same time, let’s add the nginx service to the same network as the web service, make sure web is up and running when we fire up nginx and also put the config file from our local repo where it should be in the container by mapping a volume:

```
volumes:
  — ./nginx/default.conf:/etc/nginx/conf.d/default.conf
networks:
  — backend
depends_on:
  — web
```

Now, we’ll also change the container to run a proper web server instead of a simple Django development server. We’ll opt for gunicorn, so let’s add that to our requirements:

```
echo “gunicorn” >> requirements.txt
```

It’s totally optional to also install gunicorn locally as our intention is to run the Django debug server locally and gunicorn in the container. To kick off a gunicorn server in our container, we modify our command in `docker-compose.yml` for the web service to the following:

```
command: gunicorn mysite.wsgi — bind 0.0.0.0:8001
```

For now, let’s add both `'localhost'` as well as our `WEB_HOST` to the list of allowed hosts in our Django `settings.py`. This allows us to access our webapp when it is running locally as well as inside a container.

```
ALLOWED_HOSTS = [WEB_HOST, ‘localhost’]
```

We may otherwise come across an error page saying “DisallowedHost” (if Django is in Debug mode) or just a Bad Request (400) error.

Now, if we hit our nginx service at [`http://localhost:8088/admin`](http://localhost:8088/admin), we’ll be served our admin login page but it looks different to what we are used to. It’s because our gunicorn server is not intended to serve static files, so we will have to configure nginx to instead serve the static files. To this end, we add the following lines to our `default.conf`:

```
location /static {
 alias /code/static;
 }
```

Next, we approach the Django side of static files. At first let’s tell Django where we would like our directory for static files in its `settings.py`

```
STATIC_ROOT = os.path.join(BASE_DIR, ‘static’)
````

We’ll update a our `docker-compose.yml` file to map our local directory with the static files to a directory in our container:

```
volumes:
  — ./nginx/default.conf:/etc/nginx/conf.d/default.conf
  — ./mysite/static:/code/static

```

Finally, we run `python mysite/manage.py collectstatic` and all static files for our app are pulled into the chosen directory. We should see the difference by refreshing our page on [`http://localhost:8088/admin`](http://localhost:8088/admin) — it should now look familiar. When we hit our web service directly on [`http://localhost:8001`](http://localhost:8001), we see the static files cannot be found since they are being served by the nginx service.

We can also see that in our logs these things are recorded. There is quite a bit of information there. For example, nginx informs us about all the files it served on the request we have just sent off and the status codes 200, meaning success, is good news. However, the favicon could not be found as we are also notified by the log of the web server. For now, let’s just add this line to our nginx config, so that it stops complaining about a favicon:

```
location = /favicon.ico {access_log off;log_not_found off; }
```

Ok, this stack is in pretty good shape by now. Let’s make the data of our Postgres `db` service persist by mapping it to a local volume, which is very similar to what we have done for the SQLite data (Also let’s not forget to add that directory to our `.gitignore`!).

```
volumes:
 — ./postgres-data:/var/lib/postgresql/data
```

### The fruits of our labor

Now, a quick recap of what our setup looks like. We have multiple services running side by side now:

 * Our main endpoint, the nginx service (http://localhost:8088)
 * Direct endpoint of the app server (http://localhost:8001)
 * The Postgres admin endpoint (http://localhost:8080)
 * Our Postgres `db` service listening for connections (but not HTTP requests)  * (localhost:5432)
 * If we run an app locally, we can also access it (http://localhost:8000)

I would say we have already come along way from where the Django tutorial started off. All but the local app above are running once we execute one simple command: `docker-compose up`. Almost all of our infrastructure is defined in code and configuration is transparent. We also made our life easier by having a data migration handle the creation of a superuser. In order to get stuff up and running from a blank slate, one would have to run only two commands:

```
docker-compose up
docker-compose exec web python manage.py migrate
```

Ok, granted we’d also have to add the `.env` file and create a virtual environment — something to automate at some point perhaps. Our database is persisted however, so if we tear down our containers, we can start everything from scratch and our admin user is still there and we can login to the `admin/` endpoint and also the `db-admin` service.

Now, it would be prudent to separate the configuration for our various environments a bit more carefully and Docker has some neat functionality. First off, we move all our migration specific config into a separate YAML file (`docker-compose.migrate.yml`), such as the creation of our superuser. Let’s pool all the setup tasks in one bash script that gets invoked inside this specific container, such as collecting static assets and running migrations. As a side note, this service will have to wait for the database inside the `db` service to be ready to accept connections, otherwise it will fall over. This is called [controlling the startup order](https://docs.docker.com/compose/startup-order/). Luckily, there is a neat little [bash script](https://github.com/eficode/wait-for) that we can use to make the migrate service check for services being ready. Our service is started with the following commands, which wait for database connections being ready and runs migration as a collective:

```
command: [“./wait-for.sh”, “db:5432”, “ — “, “./run-migrations.sh”]
```

We can run these one off tasks by explicitly pointing Docker to this YAML file and make sure to remove the container once it’s all done: 

```
docker-compose -f docker-compose.migrate.yml run migrate -d — rm
```

At this point, let’s follow a similar approach to move all the development specific configuration into `docker-compose.override.yml`. Docker will automatically read this file and use it override the config in the base `docker-compose.yml`. Hence, we can keep debug flags, admin consoles, open ports and the mapping of directories separate from the basic service definitions.

### Logging

Finally, let’s touch on the topic of logging. I say “touch” because the topic is worth many articles in itself. In fact, logging has turned into a whole industry — there are multiple companies like Splunk and SumoLogic that offer managed solution to handle logging. Also all the cloud providers offer such services and it often makes sense to go with such a solution before you start managing log aggregators yourself. Specifically if your goal is to develop. So, while we are on a local machine, i.e. our laptops, we’ll keep our logs going to the standard output. That’s the most straight-forward way of keeping an eye on things. Also, all apps and services inside containers should stream to stdout as that’s where docker will catch those logs and pipe them to your local stdout. Now, Docker also has many other ways to handle logging and this can be specified by the logging drivers for each service individually.

So we could also run a log aggregator in a Docker container, and this image contains the entire ELK — that stands for ElasticSearch, LogStach and Kibana. However, things will get intricate at this point. Depending on which logging driver we opt for, we could end up sending logs directly to ElasticSearch, but others would stream to the LogStach services, while yet other options would require a separate service to handle logs from all places and send them to their respective destination. Feel free to go down that rabbit hole and marvel at how complex things will get. No need for an explanation why manages log aggregation services are doing good business. So, unless you are actually setting up shared staging or production environments, let the logs in the development stage go to the standard output.

## What's next

Right, this was all DevOps now - it's time to actually make this app do something. There are countless examples of what the app could do - To-Do list is a classic one. Or it could be an Agile board. Maybe a chat app, or a multiplayer online game. That'll be part of another article.