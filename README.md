
# Easily create a small private Mastodon instance

Set up a simple Mastodon instance in AWS.

This configuration provides no redundancy or scaling, as its meant for a private instance with only a few accounts on it.

Its runs all the components on one ec2 instances to reduce cost.

* Easy to deploy
* Easy to teardown
* Estimated cost is less than $30/mo

## What is Mastodon

Mastodon is a decentralized social network. You can create an account on an instance, and post messages to the world or follow other people to see what they've posted.

## Why Another Terraform Project?

There are lots of great terraform and helm repos that will help you setup a complete Mastodon instance. But those are usually geared towards infrastructure that can scale, and deal 1000 more users. 

If you just want to run a small instance for you and a few friends, then thats over-kill.

Its also expensive. Managed services and scalability comes at a premium. Just running the same software on an small ec2 instance and managing it yourself is a great deal cheaper in the long run.


## Other Options

If you just want someone else to manage things, there are private mastodon providers for as little as $5/mo.

This project is for people that want to "own" their own instance, get their hands dirty, customize it. Maybe even hack it.

# Setup

AWS
  1. Create your AWS account
  2. Generate and download your IAM credentials
  3. Use `aws configure` to put those credentials in your local env, and choose a region\
  This will allow you to run the terraform commands to create/destroy tings in AWS.

Domain Name
  1. Register a domain name with your preferred registrar\
  There are no special instructions here for using AWS to register a domain.
  2. In your domain registrar's interface, point your name servers to the Amazon owned nameservers. 
Now AWS can use your domain.

Terraform
  1. clone this repo.
  1. `cp terraform.tfvars.example terraform.tfvars` and fill in the values.
  2. `terraform init`
  3. `terraform apply`\
  type "yes" when it asks to apply.

Your mastadon server is up and running.  It may take a minute or two the first time.

[https://&lt;your domain&gt;](https://your-domain)


Sign up for an account and off you go.

Don't forget to follow @dragonfax@sosh.space


# Feedback

If you give it a try and have problems, give me feedback by filling out a github Issue.

# Later

4. Save your terraform state (its in this directory) somewhere safe and secure.\
It has the private keys to your instance, and it also has important files terraform uses if you need to make changes to the infrastructure.
5. You'll want to to start the email verification for the domain. Otherwise your instance can't send emails. \
`TF_VAR_email_verify=true terraform apply`\
It'll fail fast because of a bug in AWS. But just ignore it. It'll keep going in the background and eventually succeed. 
8. See below on how to become the owner of the instance. 
9. From there you can configure Mastondon through its web site.


# Fooling Around

##  Accessing the ec2 host

You can ssh into the box with\
`ssh -i keys/ec2.pem ec2-user@your-mastodon.site`

The databases are all in /opt/data, which is a seperate ebs volume and has snapshots for backups.

To see the servers
1. `cd /opt`
2. `docker-compose ps`

Only nginx listens on an external port. Everything else is sandboxed in the docker vm.

After signing up on the website, use this command, from the host, to give your account ownership rights.\
`docker-compose exec web tootctl accounts modify <your username> --role Owner`

## Double-tap Rule

When ever you rerun a `terraform apply`, and it needs to restart the instance, you'll have to run a second `terraform apply` in order to pick up changes to the IP address. AWS changes it everytime the server reboots.

## Commiting Your Changes

So you've made changes and want to commit them back to your own private repo for safe keeping?

Github doesn't let you fork a public repo into a private repo. But its easy to fake that feature.

1. clone this repo, if you haven't done so already
2. create your new private repo on the web site
3. `git remote add mine <your private git repo url>`
4. `git push mine main:main`

And that will copy this repo into your new private repo.

Remember that if you don't also commit your terraform state files, then you won't be able to clone and apply terraform from another computer.

## Ideas

Costs could be further reduced by using a Spot Instance. But that would require restarting the instance when AWS terminates it.

Cost allocation tags could be used to see, roughly, the cost of the instance seperate from the other resources in your AWS account.

There are additional crontabs that can be setup for instance maintenance and cleanup.

I'm sure some people will want to run their instance ona subdomain.

We could aleviate the doubl-tap rule by using an elastic IP.

## Common Issues

### DNS Name Servers

DNS nameserver changes can take a long time to propogate. If you just pointed your registrars to AWS name servers, then it could take up to 2 days for other hosts on the internet to see that change. 

Even if you clear your local dns cache, the dns cache on letsencrypt might still have the old value. 

If you have issues with this, just start/stop the instance after a day and then `terraform apply`, again, to get the route53 DNS updated (double-tap rule).

You can always stop the instance, in the meantime, to save the money while you wait.

### Creating Accounts

You can also create your account from the host with\
`/usr/local/bin/docker-compose exec web tootctl accounts create <usernmae> --email=<email> --confirmed --role Owner`

## Time To Quit?

1. from the host\
`docker-compose exec web tootctl self-destruct`\
This is important so that other instances know your gone.
2. remove the "prevent_destroy" lines from the *.tf files. These are a safe-guard from losing important data.
3. `terraform destroy`\
This should remove everything that was created.

But just incase, check for 
* ec2 volume snapshots
* Leftover contents of the s3 bucket that kept it from being deleted.

*made for Mastodon 4.0*
