Patient Private Attributes
======================

## Overview

This demo is a user registration web service to create and login patients. Each patient has
a typical login and password, plus extended set of sensitive *attributes*, such us an 
Electronic Medical Record (EMR) Id, and a security question and answer.

The user registration service creates a ConjurEnvironment (key escrow)
for each new patient, which contains the  private attributes.
These private attributes are readable, but not writeable, by the user.
They are also readable by a support team, who may provide patient assistance with login.

The attributes are writeable by the patient login service, and also by an admin group
which oversees the application.

## Permissions Model

### Groups

* Administrators
* Support Team
* Patient Service web application servers / VMs

A *host* identity is created for the patient service web application, and added to the
service group. 

## Runtime Operation

When a new user is created, a new Environment is created and owned by the patient service.
The Environment is populated with the EMRID and the security question. The patient and the
support team are granted permission to read the Environment.

Web service endpoints are:

* **POST /users** Create a new patient record
* **GET /current-user** View the current logged-in user information
* **GET /users/:login/attributes** View the extended attributes for a user
* **PUT /users/:login/attributes/:key** Update a user extended attribute

## Demo

```
$ # Login as Alice
$ conjur authn:login -u $ns-alice -p $alice_api_key

$ # Alice can view her user attributes
$ curl -H "`conjur authn:authenticate -H`" localhost:4567/current-user
{
  "login": "j98r80-alice",
  "userid": "host/j98r80/patient-identity/1",
  "ownerid": "sandbox:host:j98r80/patient-identity/1",
  "uidnumber": 1151,
  "roleid": "sandbox:user:j98r80-alice",
  "resource_identifier": "sandbox:user:j98r80-alice"
}

$ # Alice can view her extended attributes
$ curl -H "`conjur authn:authenticate -H`" localhost:4567/user/$ns-alice/attributes
{
  "emrid": "EMR-12ACEB",
  "security-question": "{ \"question\": \"In what city were you born?\", \"answer\": \"Newton\" }"
}

$ # Alice cannot update her EMRID
$ curl -i -X PUT -H "`conjur authn:authenticate -H`" localhost:4567/user/$ns-alice/attributes/emrid --data "foobar"
HTTP/1.1 403 Forbidden 
Content-Type: text/html;charset=utf-8
Content-Length: 0
X-Xss-Protection: 1; mode=block
X-Content-Type-Options: nosniff
X-Frame-Options: SAMEORIGIN
Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-05-14)
Date: Tue, 20 Aug 2013 20:27:52 GMT
Connection: Keep-Alive

$ # Login as admin
$ conjur authn:login -u admin

$ # Admin can update extended attributes
$ curl -i -X PUT -H "`conjur authn:authenticate -H`" localhost:4567/user/$ns-alice/attributes/emrid --data "EMR-ABC123"
HTTP/1.1 204 No Content 
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-05-14)
Date: Tue, 20 Aug 2013 20:29:25 GMT
Connection: Keep-Alive

$ # Show that the change has been applied
$ curl -H "`conjur authn:authenticate -H`" localhost:4567/user/$ns-alice/attributes
{
  "emrid": "EMR-ABC123",
  "security-question": "{ \"question\": \"In what city were you born?\", \"answer\": \"Newton\" }"
}

$ # A new user can be created through the service
$ curl -X POST localhost:4567/users --data "login=$ns-susan&emrid=EMR-SUSAN1&question=Birth+city&answer=Chicago"
{
  "login": "j98r80-susan",
  "userid": "host/j98r80/patient-identity/1",
  "ownerid": "sandbox:host:j98r80/patient-identity/1",
  "uidnumber": 1159,
  "roleid": "sandbox:user:j98r80-susan",
  "resource_identifier": "sandbox:user:j98r80-susan",
  "api_key": "<snip>"
}

$ # The new user can login and view her record

$ conjur authn:login -u j98r80-susan -p $susan_api_key
$ curl -H "`conjur authn:authenticate -H`" localhost:4567/current-user
{
  "login": "j98r80-susan",
  "userid": "host/j98r80/patient-identity/1",
  "ownerid": "sandbox:host:j98r80/patient-identity/1",
  "uidnumber": 1159,
  "roleid": "sandbox:user:j98r80-susan",
  "resource_identifier": "sandbox:user:j98r80-susan"
}

$ # She cannot view another user's attributes
$ curl -H "`conjur authn:authenticate -H`" localhost:4567/user/$ns-alice/attributes
RestClient::Forbidden: 403 Forbidden

$ # But she can view her own
$ curl -H "`conjur authn:authenticate -H`" localhost:4567/user/$ns-susan/attributes
{
  "emrid": "EMR-SUSAN1",
  "security-question": "{\"question\":\"Birth city\",\"answer\":\"Chicago\"}"
}
```
