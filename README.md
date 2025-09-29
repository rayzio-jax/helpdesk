# Helpdesk

## Methods
* Pubsub - Clear
* Polling - In-progress

# How to run
Before running this project, make sure you already have these
## What do you need?
1. Google Cloud Project with Gmail API enabled & configured OAuth
2. Database locally or serverless (I prefer to use PostgreSQL since I'm using Postgre in this project)
## Gmail API required scopes
* Minimal scope
1. https://www.googleapis.com/auth/gmail.readonly -> View your email messages and settings
2. https://www.googleapis.com/auth/gmail.send -> Send email on your behalf
* Full access scope
1. https://www.googleapis.com/auth/gmail.modify -> Read, compose, and send emails from your Gmail account

## Pub/Sub Setup
1. Go to [Google Cloud Console](http://console.cloud.google.com/)
2. Go to Menu > View all products > Analytics tab > Pub/Sub
3. In Topics > Create new topic and name it as you like (e.g gmail-push-notification) <br>
   Copy that full topic name as `GOOGLE_PUBSUB_TOPIC`
4. In Subscriptions > Your post-made subscriptions > Edit > Change `Delivery type` to `Push` and set your callback url (url must be `https`, you can use ngrok for local testing)
5. Go to Menu > IAM & Admin > IAM > In View by principals, click `Grant access` > Add `gmail-api-push@system.gserviceaccount.com` as new principal, select the role `Pub/Sub Publisher`

## Run
1. Clone this project
```bash
git clone https://github.com/rayzio-jax/helpdesk.git
```
2. Bundle install
```bash
bundle install
```
3. Run development mode
```bash
bin/dev
```
