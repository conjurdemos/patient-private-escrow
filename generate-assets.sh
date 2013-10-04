ns=`conjur id:create`
echo Namespace: $ns

conjur group:create $ns/admin
conjur group:create --as-group $ns/admin $ns/teams/support
conjur group:create --as-group $ns/admin $ns/services/patient-identity

host_api_key=`conjur host:create --as-group $ns/admin $ns/patient-identity/1 | jsonfield api_key`
echo Service API Key: $host_api_key
conjur group:members:add $ns/services/patient-identity host:$ns/patient-identity/1

conjur authn:login -u host/$ns/patient-identity/1 --password=$host_api_key

alice_api_key=`conjur user:create $ns-alice --no-password | jsonfield api_key`
echo Alice API Key: $alice_api_key

conjur asset:create environment:$ns/patient-attributes/$ns-alice

conjur asset:members:add environment:$ns/patient-attributes/$ns-alice use_variable user:$ns-alice
conjur asset:members:add environment:$ns/patient-attributes/$ns-alice use_variable group:$ns/teams/support

conjur environment:variables:create $ns/patient-attributes/$ns-alice security-question security-question application/json '{ "question": "In what city were you born?", "answer": "Newton" }'

conjur environment:variables:create $ns/patient-attributes/$ns-alice emrid emrid text/plain "EMR-12ACEB"

# Demonstrate that Alice can read from her password escrow
conjur authn:login -u $ns-alice --password=$alice_api_key

conjur environment:value $ns/patient-attributes/$ns-alice security-question
conjur environment:value $ns/patient-attributes/$ns-alice emrid

# Alice cannot update values in the escrow
conjur environment:variables:update $ns/patient-attributes/$ns-alice emrid a-fake-id
