# Adding Users

Users in Silver are provisioned through the [Thunder ID](https://github.com/thunder-id/thunderid) console that ships with the platform. This guide walks through adding users via the console.

## Prerequisites

- Silver is running (see [Server Setup](../README.md#server-setup) in the main README).
- You can reach the Thunder console at `https://<your-domain>:8090`.
- You have Thunder admin credentials.

## Steps

### 1. Sign in to the Thunder console

Open `https://<your-domain>:8090` in your browser and sign in with your admin credentials.

### 2. Create a user schema

Define a user schema that includes the fields needed for an email user — at minimum, `username` and `password`.

### 3. Assign the schema to an organization unit

Assign the schema you just created to the `silver` organization unit (or another organization unit you want the users to belong to).

### 4. Add users

Under the target organization unit, add users using one of the following:

- **Set a password directly** — supply a `username` and `password` for the user.
- **Send an invitation link** — provide the user's secondary email address; Thunder will email them an invitation link to set their own password.

## Programmatic provisioning

For bulk or scripted user creation against the Thunder REST API, see [`scripts/user/create_test_users.sh`](../scripts/user/create_test_users.sh) for a working example that authenticates with Thunder, looks up the `silver` organization unit, and creates users via `POST /users`. The authentication helper lives in [`scripts/utils/thunder-auth.sh`](../scripts/utils/thunder-auth.sh).

Further details on the Silver ↔ Thunder integration are in the [Thunder API Consumer Contract Guide for Silver](Thunder-API-Consumer-Contract-Guide-for-Silver.md).
