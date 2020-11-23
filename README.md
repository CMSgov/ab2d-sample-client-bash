
# Welcome to the AB2D Bash Sample Repo 

Our API Clients are open source. This repo contains *sample* Bash script which demonstrate how to pull data from the AB2D API Production environment.

This may be a great starting point for your engineering or development teams however it is important to note that the AB2D team does **not** regularly maintain the sample clients. Additionally, a best-effort was made to ensure the clients are secure but they have **not** undergone comprehensive formal security testing. Each user/organization is responsible for conducting their own review and testing prior to implementation

Use of these clients in the sandbox environment, can allow for testing, and if a mistake is made no PII/PHI is compromised. The sandbox environment is publicly available and all of the data in it is synthetic (**not** real)

## Production Use Disclaimer:

These clients are provided as examples, but they are fully functioning (with some modifications) in the production environment. Feel free to use them as a reference. When used in production (even for testing purposes), these clients have the ability to download PII/PHI information. You should therefore ensure the environment in which these scripts are run is secured in a way to allow for storage of PII/PHI. Additionally, when used in the production environment the scripts will require use of your production credentials. As such, please ensure that your credentials are handled in a secure manner and not printed to logs or the terminal. Ensuring the privacy of data is the responsibility of each user and/or organization.



## Bash Client

A simple client for starting a job in sandbox or production, monitor that job,
and download the results. To prevent issues these scripts persist the job
id and list of files generated.

This script will not overwrite already existing export files.

```
Usage: 
  bootstrap (-prod | -sandbox) --auth <base64 username:password> [--contract <contract number>] [--directory <dir>]
  run-job (-prod | -sandbox) --auth <base64 username:password> [--contract <contract number>] [--directory <dir>]
  start-job
  monitor-job
  download-results

Arguments:
  -sandbox -- if running against ab2d sandbox environment
  -prod -- if running against ab2d production environment
  --auth -- base64 encoded "clientid:password" OR a path to a file containing the base64
            credentials. The path must end in ".base64"
  --contract -- if searching specific contract then give contract number ex. Z0001
  --directory -- if you want files and job info saved to specific directory
```

Files:

1. <directory>/jobId.txt -- id of the job created
1. <directory>/response.json -- list of files to download 
1. <directory>/*.ndjson -- downloaded results of exports 

Limitations:

1. Assumes all scripts use the same directory
2. Assumes all scripts use the same base64 encoded AUTH token saved to a file

Example:

If you want to:
1. Start a job running against production
1. Using credentials in `my-orgs-creds.base64`
1. Pull a specific contract named 'ABCDE'
1. And save all results for this job to the directory /opt/foo

Then run the following command
`source ./bootstrap.sh -prod --auth my-orgs-creds.base64 --contract ABCDE --directory /opt/foo &&
 ./start-job.sh && ./monitor-job.sh && ./download-results.sh`


## Scripts Included

1. bootstrap.sh: prepare environment variables necessary for other scripts using command line arguments
1. start-job.sh: start a job given an auth token, contract, and environment
1. monitor-job.sh: monitor a running job until it completes
1. download-results.sh: download results from a job that has been run
1. run-job.sh: aggregation of the first four scripts

The last script combines the first four steps into one script.

### Other resources included

1. fn_get_token.sh: take a base64 encoded secret and retrieve a JWT token

## Extended Example Instructions

For this example the job is run against sandbox.

### Running Scripts Individually

1. Set the OKTA_CLIENT_ID and OKTA_CLIENT_PASSWORD
   ```bash
   OKTA_CLIENT_ID=<client id>
   OKTA_CLIENT_PASSWORD=<client password>
   ```
1. Set the `AUTH_FILE=<auth-file>` 
1. Create the AUTH token `echo -n "${OKTA_CLIENT_ID}:${OKTA_CLIENT_PASSWORD}" | base64 > $AUTH_FILE`
and copy it to a file. Example file: `auth-token.base64`.
1. Run `source bootstrap.sh -prod --directory <directory> --auth $AUTH_FILE` to set environment variables for a job.
1. Run `./start-job.sh` to start a job. If successful a file containing
the job id will be saved in `<directory>/jobId.txt`
1. Run `./monitor-job.sh` which will monitor the state of the running job. When the job
finished the full HTTP response will be saved to `<directory>/response.json`
1. Run `./download-results.sh` to get the files. This will only download the files once. Running again
will not overwrite the files but will also not download anything.

### Running Aggregate Script

1. Set the OKTA_CLIENT_ID and OKTA_CLIENT_PASSWORD
   ```bash
   OKTA_CLIENT_ID=<client id>
   OKTA_CLIENT_PASSWORD=<client password>
   ```
1. Set the `AUTH_FILE=<auth-file>` 
1. Create the AUTH token `echo -n "${OKTA_CLIENT_ID}:${OKTA_CLIENT_PASSWORD}" | base64 > $AUTH_FILE`
and copy it to a file. Example file: `auth-token.base64`.
1. Run `./run-job.sh -prod --directory <directory> --auth $AUTH_FILE` to start, monitor, and download results from a job.
