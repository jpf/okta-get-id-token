#! /usr/bin/env nix-shell
#! nix-shell -i bash -p curl -p jq
# get_id_token.sh
# A shell script which demonstrates how to get an OpenID Connect id_token from from Okta using the OAuth 2.0 "Implicit Flow"
# Author: Joel Franusic <joel.franusic@okta.com>
# 
# Copyright © 2016, Okta, Inc.
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#   http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

curl="curl"
jq="jq"

base_url=""
client_id=""
origin=""
username=""
password=""
verbose=0

while getopts ":b:c:o:u:p:v" OPTION
do
    case $OPTION in
    b)
        base_url="$OPTARG"
    ;;
    c)
        client_id="$OPTARG"
    ;;
    o)
        origin="$OPTARG"
    ;;
    u)
        username="$OPTARG"
    ;;
    p)
        password="$OPTARG"
    ;;
    v)
        verbose=1
    ;;
    [?])
        echo "Usage: $0 -b base_url -c client_id -o origin -u username -p password" >&2
        echo ""
        echo "Example:"
        echo "$0 -b 'https://example.okta.com' -c aBCdEf0GhiJkLMno1pq2 -u AzureDiamond -p hunter2 -o 'https://example.net/your_application'"
        exit 1
    ;;
    esac
done

redirect_uri=$(curl --silent --output /dev/null --write-out %{url_effective} --get --data-urlencode "$origin" "" | cut -d '?' -f 2)
if [ $verbose -eq 1 ]; then
    echo "Redirect URI: '${redirect_uri}'"
fi

rv=$(curl --silent "${base_url}/api/v1/authn" \
          -H "Origin: ${origin}" \
          -H 'Content-Type: application/json' \
          -H 'Accept: application/json' \
          --data-binary $(printf '{"username":"%s","password":"%s"}' $username $password) )
session_token=$(echo $rv | jq -r .sessionToken )
if [ $verbose -eq 1 ]; then
    echo "First curl: '${rv}'"
fi
if [ $verbose -eq 1 ]; then
    echo "Session token: '${session_token}'"
fi

url=$(printf "%s/oauth2/v1/authorize?sessionToken=%s&client_id=%s&scope=openid+email+groups&response_type=id_token&response_mode=fragment&nonce=%s&redirect_uri=%s&state=%s" \
      $base_url \
      $session_token \
      $client_id \
      "staticNonce" \
      $redirect_uri \
      "staticState")
if [ $verbose -eq 1 ]; then
    echo "Here is the URL: '${url}'"
fi

rv=$(curl --silent -v $url 2>&1)
if [ $verbose -eq 1 ]; then
    echo "Here is the return value: "
    echo $rv
fi

id_token=$(echo "$rv" | egrep -o '^< Location: .*id_token=[[:alnum:]_\.\-]*' | cut -d \= -f 2)
echo $id_token
