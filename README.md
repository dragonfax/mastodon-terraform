
# Easily create a small private Mastodon instance

## purpose

sets up a simple mastodon instance in AWS

provides no redudancy or scaling.
as its meant for a private instance with only a few people on it.

runs all the servers on one ec2 instances to reduce cost.

easy to deploy.
easy to teardown.

estimated cost is less than $30/mo

## why

There are lots of great terraform and helm repos that will help you setup a complete Mastodon instance. But those are usually geared towards infrastructure that can scale, and deal 1000 more users. 

If you just want to run and instance for you and a few friends. then thats over kill.

Its also expensive. Managed services and scalability comes at a premium. Just running the same software on an ec2 instance and managing it yourself is a great deal cheaper in the long run.


## Other options


if you want someone else to handle the instance, there are private mastodon providers for as little as $5/mo

this is for people that want to "own" their own instance, customize it. maybe even hack it.


# setup

1. create your AWS account
2. create your iam user credentials
3. use aws config to put those credentials in your local env, and choose a region
This is to allow you to run the terraform commands to create/destroy tings in AWS.
1. register a domain name
there are no special instructions here for using AWS to register it.
2. in your domain registrar's interface, point your name servers to the Amazon owned ones. 
Now AWS can use your domain.
3. copy terraform.tfvars.example and fill in the values.
3. `terraform init`
3. `terraform apply`
Your mastadon server is up and running.  It may take a minute or two the first time.
4. save your terraform state (its in this directory) somewhere save and secure.

[https://&lt;your domain&gt;](https://your-domain)

you'll want to sign up for an account.

follow @dragonfax@sosh.space

see below on how to become the owner. 
from there you can configure Mastondon through its web site.


# fooling around

##  the ec2 host.

you can ssh into the box with 

`ssh -i keys/ec2.pem ec2-user@sosh.space`

the databases are all in /opt/data which is a seperate ebs volume and has snapshots.

`cd /opt`

and you can run 

`docker-compose ps`


only nginx listens on an external port. everything else is sandboxed in the docker vm.


after signing up on the website, use a command to give your account ownership rights.

`docker-compose exec web tootctl accounts modify <your username> --role Owner`


## double-tap rule

when ever you rerun a terraform apply, after the first one, you'll have to do it a second time to update the dns ip. If you changed anyhthing that will cause AWS to restart the instance. (it gets a new IP, but too late for terraform to pick it up)

You can aleviate this by using an elastic IP.

## commiting your changes

So you've made changes and want to commit them back to your own private repo for safe keeping?

github doesn't let you fork public repos into a private repo but its easy to fake the functionality.

1. clone this repo, if you haven't done so already
2. create your new private repo on the web site
3. `git remote add mine <your private git repo url>`
4. `git push mine main:main`

and that will copy this repo and its history into your new private repo.



remember that if you don't also commit your terraform state files, then you won't be able to clone and apply terraform from another location.

## if you decide to quite

1. run a toolctl self destruct
2. remove the "prevent_destroy" lines from the *.tf files
3. terraform destroy

This should leave nothing in your aws account that this repo created.

But check for 
* snapshots.
* Leftover contents of the s3 bucket that kept it from being deleted.



*made for Mastodon 4.0*
