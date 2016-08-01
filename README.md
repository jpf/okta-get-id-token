# Introduction

`get_id_token.sh` is a Bash [shell script](https://en.wikipedia.org/wiki/Shell_script) that will fetch an [OpenID
Connect](https://en.wikipedia.org/wiki/OpenID_Connect) `id_token` from Okta.

Below is an example of how `get_id_token.sh` could be used to fetch an
`id_token` for a user named "example.user" who is assigned to an Okta
application with the `client_id` of "aBCdEf0GhiJkLMno1pq2" in the
"example.oktapreview.com" Okta org:

Running the command above will return a JWT similar to the one
below:

# Installing

This shell script depends on `curl` and `jq` to run. The easiest way
to install these dependencies is to use the [Nix package manager](https://nixos.org/nix/),
which will automatically install these dependencies for you if you
run the commands below.

> Note: While Nix is the easiest way to install the dependencies for
> this script, Nix will download over 600 [MiB](https://en.wikipedia.org/wiki/Mebibyte) of packages to install
> `curl` and `jq`. If you don't want to use the Nix package manager, you
> can install `curl` and `jq` using your preferred package manager and
> then change the interpreter on the first line of `get_id_token.sh`
> from "`/usr/bin/env nix-shell`" to "`/bin/bash`"

Here is how to install `get_id_token.sh` on your system using the Nix
package manager on GNU/Linux or macOS systems:

1.  Install the Nix package manager:
    
        curl https://nixos.org/nix/install | sh
2.  Download the `get_id_token.sh` shell script to your system
    
        git clone git@github.com:jpf/okta-get-id-token.git
3.  Change to the directory containing the `get_id_token.sh` shell
    script
    
        cd okta-get-id-token
4.  Run the shell script:
    
        ./get_id_token.sh -h

# Creating an Okta application for OpenID Connect

Follow the steps below if you haven't yet created an Okta
application with OpenID Connect support.

-   Log in to your Okta org as a user with administrator access.
-   Click on the "Admin" button.
-   Click on the "Add Applications" link in the right-hand "Shortcuts" sidebar.
-   Click on the "Create New App" button located on the left-hand side
    of the Add Application page.
-   A dialog box will open:
    -   For the purposes of this demonstration, leave "Platform" set to
        the "Web" option.
    -   Set the "Sign on method" to the "OpenID Connect" option.
    -   Click the "Create" button.
-   Select a name for your application. Use "get\_id\_token.sh" if you
    can't think of a good name.
-   Click "Next"
-   For the purposes of this demonstration, enter
    "<https://example.net/your_application>" as the Redirect URI.
-   Click "Finish"
-   You should now see the "General" tab of the OpenID Connect
    application that you just created.
-   Scroll down and copy the "Client ID" for the application that you created.
-   Click the "People" tab.
-   Click the "Assign to People" button.
-   Search for a user to assign to the application.
-   Click the "Assign" button for the user you want to assign to the application.
-   Click the "Save and Go Back" button.
-   Click the "Done" button.

Once you have created an Okta application and assigned a user to
that application, run the command in the section below to fetch an
`id_token` for that user.

# Using

Here is an example command that will fetch an `id_token` from Okta.

    ./get_id_token.sh -b 'https://example.okta.com' -c aBCdEf0GhiJkLMno1pq2 -u AzureDiamond -p hunter2 -o 'https://example.net/your_application'"

Here are what each of the options do:

**-b** is the **Base URL** for your Okta org.

**-c** is the **Client ID** for the Okta application that you created.

**-u** is the **Username** for a user assigned to the Okta application.

**-p** is the **Password** for the user.

**-o** is the **Origin**, one of the white listed URLs allowed to request an
`id_token` for the Client ID.

# How it works

At a high level, the `get_id_token.sh` script does the following:

1.  Initialize runtime dependencies using `nix-shell`
2.  Parse command line flags
3.  Fetch a [Session Token](http://developer.okta.com/docs/api/resources/sessions#session-token) from Okta via the Okta API
4.  Request an OpenID Connect `id_token` from the Okta API

Each section is covered in detail below.

## Initializing runtime dependencies using nix-shell

We start with a [shebang](https://en.wikipedia.org/wiki/Shebang_(Unix)) which specifies that this script is to
interpreted by `nix-shell` - which gives this script the ability to
configure its own dependencies automatically via the Nix package
manager.

    #! /usr/bin/env nix-shell
    #! nix-shell -i bash -p curl -p jq
    # get_id_token.sh
    # A shell script which demonstrates how to get an OpenID Connect id_token from from Okta using the OAuth 2.0 "Implicit Flow"
    # Author: Joel Franusic <joel.franusic@okta.com>

## Parsing command line flags

Next we parse the command line flags into local variables. The
StackOverflow article on [Parsing arguments/options/flags in a bash
script](http://stackoverflow.com/questions/8175000/parsing-arguments-options-flags-in-a-bash-script) has more details on parsing command line arguments in a Bash script.

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

## Fetching a Session Token from Okta via the Okta API

The code below uses `curl` to [URL encode](https://en.wikipedia.org/wiki/Percent-encoding) the redirect URL. For
example, if our redirect URL is `https://example.com` this code will
convert that string into `https%3A%2F%2Fexample.com`

    redirect_uri=$(curl --silent --output /dev/null --write-out %{url_effective} --get --data-urlencode "$origin" "" | cut -d '?' -f 2)

If the `-v` flag was set, we print out some extra debugging information:

    if [ $verbose -eq 1 ]; then
        echo "Redirect URI: '${redirect_uri}'"
    fi

Once we have a properly encoded URL, we construct a `curl` command to
fetch an Okta session token from Okta using Okta's [/authn](http://developer.okta.com/docs/api/resources/authn.html#primary-authentication) API endpoint:

    rv=$(curl --silent "${base_url}/api/v1/authn" \
              -H "Origin: ${origin}" \
              -H 'Content-Type: application/json' \
              -H 'Accept: application/json' \
              --data-binary $(printf '{"username":"%s","password":"%s"}' $username $password) )
    session_token=$(echo $rv | jq -r .sessionToken )

If the `-v` flag was set, we print out some extra debugging information:

    if [ $verbose -eq 1 ]; then
        echo "First curl: '${rv}'"
    fi
    if [ $verbose -eq 1 ]; then
        echo "Session token: '${session_token}'"
    fi

## Requesting an OpenID Connect id\_token from the Okta API

Then, using our Okta session token, we construct a `curl` command to
make an [OAuth 2.0 authentication request](http://developer.okta.com/docs/api/resources/oauth2.html#authentication-request) to Okta, asking for an `id_token`:

Note that we are requesting the "openid", "email", and "groups"
scopes" via the `scopes` query parameter.

    url=$(printf "%s/oauth2/v1/authorize?sessionToken=%s&client_id=%s&scope=openid+email+groups&response_type=id_token&response_mode=fragment&nonce=%s&redirect_uri=%s&state=%s" \
          $base_url \
          $session_token \
          $client_id \
          "staticNonce" \
          $redirect_uri \
          "staticState")

If the `-v` flag was set, we print out some extra debugging information:

    if [ $verbose -eq 1 ]; then
        echo "Here is the URL: '${url}'"
    fi

Then, we run the `curl` command, capturing the return value into a
local variable named `rv`:

    rv=$(curl --silent -v $url 2>&1)

If the `-v` flag was set, we print out some extra debugging
information:

    if [ $verbose -eq 1 ]; then
        echo "Here is the return value: "
        echo $rv
    fi

Finally, we parse out the `id_token` from the output of the `curl`
command, and print the value of the `id_token` on standard out:

    id_token=$(echo "$rv" | egrep -o '^< Location: .*id_token=[[:alnum:]_\.\-]*' | cut -d \= -f 2)
    echo $id_token

# Dependencies

This script depends on the command line tools listed below. These
requirements should be automatically included via the `nix-shell`
directives in the script, but are listed below for the sake of
completeness.

| Name | Version | Description | License |
| ---- | --- | --- | --- |
| [curl](https://curl.haxx.se/) | 7.47.1 | Command line tool for transferring data with URL syntax | [MIT/X](https://curl.haxx.se/docs/copyright.html) |
| [jq](https://stedolan.github.io/jq/) | 1.5 | A lightweight and flexible command-line JSON processor | [MIT](https://github.com/stedolan/jq/blob/master/COPYING) |

# License information

    Copyright © 2016, Okta, Inc.
    
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
    
      http://www.apache.org/licenses/LICENSE-2.0
    
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.