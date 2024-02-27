
# Welcome to the AB2D Bash Sample Repo 

Our API Clients are open source. This repo contains *sample* Bash script which demonstrate how to pull data 
from the AB2D API Production environment.

This may be a great starting point for your engineering or development teams however it is important to note that the AB2D team does **not** regularly maintain the sample clients. Additionally, a best-effort was made to ensure the clients are secure, but they have **not** undergone comprehensive formal security testing. Each user/organization is responsible for conducting their own review and testing prior to implementation

Use of these clients in the sandbox environment allows for safe testing and ensures no PII/PHI will not be compromised if a mistake is made.
The sandbox environment is publicly available and all the data in it is synthetic (**not** real).

AB2D supports both R4 and STU3 versions of the FHIR standard. FHIR R4 is available using v2 of AB2D while FHIR STU3 can 
be accessed via AB2D v1. Accordingly, this client supports both R4/v2 and STU3/v1.

## Production Use Disclaimer:

These clients are provided as examples, but they are fully functioning (with some modifications) in the production environment. Feel free to use them as a reference. When used in production (even for testing purposes), these clients have the ability to download PII/PHI information. You should therefore ensure the environment in which these scripts are run is secured in a way to allow for storage of PII/PHI. Additionally, when used in the production environment the scripts will require use of your production credentials. As such, please ensure that your credentials are handled in a secure manner and not printed to logs or the terminal. Ensuring the privacy of data is the responsibility of each user and/or organization.

## Prerequisites

The default shell for Macs is zsh, and these scripts don't work in zsh. To switch to bash, run the command `bash` from a zsh prompt.

`jq` must be installed. It is usually installed in a linux environment but on a macOS, 
you can install it by typing `brew install jq`.

## Bash Client

This bash client consists of five bash scripts that can be used to get AB2D data from either the sandbox or production. 
These scripts allow you to:
1. start a job in sandbox or production
2. monitor that job
3. download the results.

These scripts persist the job id and list of files generated in local files. This client supports both R4 (v2) and STU3 (v1) of the standard.

This script will not overwrite already existing export files.

```
Usage: 
  bootstrap (-prod | -sandbox) --auth <auth.base64> [--directory <dir>] [--since <since>] --fhir (STU3 | R4)
  run-job (-prod | -sandbox) --auth <auth.base64> [--directory <dir>] [--since <since>] --fhir (STU3 | R4)
  start-job
  monitor-job
  download-results

Arguments:
  -sandbox    -- if running against ab2d sandbox environment
  -prod       -- if running against ab2d production environment
  --auth      -- the path to a file base64 containing the base64
                 credentials encoded as "clientid:password".
  --directory -- if you want files and job info saved to specific directory
  --since     -- if you only want claims data updated or filed after a certain date specify this parameter.
                 The expected format is yyyy-MM-dd'T'HH:mm:ss.SSSXXX+/-ZZ:ZZ.
                 Example March 1, 2020 at 3 PM EST -> 2020-03-01T15:00:00.000-05:00
  --fhir      -- The FHIR version

```

### `--since` parameter

If you only want claims data updated or filed after a certain date use the `--since` parameter. The expected format follows the typical
ISO date time format of `yyyy-MM-dd'T'HH:mm:ss.SSSXXX+/-ZZ:ZZ`

For requests using FHIR R4, a default `_since` value is supplied if one is not provided. The value of the default `_since`
parameter is set to the creation date and time of a contract's last successfully searched and downloaded job.

The earliest date that `_since` works for is February 13th, 2020. Specifically: `2020-02-13T00:00:00.000-05:00`.

For requests using FHIR R4, a default `_since` value is supplied if one is not provided. The value of the default `_since` 
parameter is set to the creation date and time of a contract’s last successfully searched and downloaded job.

`--since` Examples:
1. March 1, 2020 at 3 PM EST -> `2020-03-01T15:00:00.000-05:00`
2. May 31, 2020 at 4 AM PST -> `2020-05-31T04:00:00-08:00`

### Files created by scripts 

These will be created in the directory specified by the `--directory` parameter. If no `--directory` parameter is supplied they will be created in the current directory.

1. jobId.txt -- id of the job created
2. response.json -- list of files to download 
3. *.ndjson -- downloaded results of exports 

Limitations:

1. Assumes all scripts use the same directory
2. Assumes all scripts use the same base64 encoded AUTH token saved to a file

Example:

If you want to:
1. Start a job running against production
2. Using credentials in `my-orgs-creds.base64`
3. Save all results for this job to the directory /opt/foo
4. And only get data after April 1st 2020 at 9:00 AM Eastern Time

Then run the following command

```
source ./bootstrap.sh -prod --auth my-orgs-creds.base64 --directory /opt/foo --fhir R4 --since 2020-04-01T09:00:00.000--05:00
./start-job.sh 
./monitor-job.sh 
./download-results.sh
 ```

## Creating the Base64 credentials file

The credentials files of these scripts are named using the following convention:
```credentials_<contract id>.base64```.

The examples in this document use the smallest AB2D sandbox contract: `Z0000` and its credentials.
If you want to use a different contract, replace `Z0000` with a different contract number use the
corresponding Client ID and Client Password.

For sandbox data, use Client ID and Client Password from one of the sandbox clients 
listed [here](https://ab2d.cms.gov/advanced-user-guide.html#authentication-and-authorization).
For production data, you will be given a contract id and an Okta client id and password.

## Scripts Included

1. bootstrap.sh: prepare environment variables necessary for other scripts using command line arguments
2. start-job.sh: start a job given an auth token and environment
3. monitor-job.sh: monitor a running job until it completes
4. download-results.sh: download results from a job that has been run
5. run-job.sh: aggregation of the first four scripts

The last script combines the first four steps into one script.

### Other resources included

1. fn_get_token.sh: take a base64 encoded secret and retrieve a JWT token

## Extended Example Instructions

For this example the job is run against sandbox contract `Z0000`.

### Running Aggregate Script

This downloads data with one command. This is the preferred way to run a job.

1. Set the OKTA_CLIENT_ID and OKTA_CLIENT_PASSWORD. Replace values with your Client Id and Password.
   ```bash
   OKTA_CLIENT_ID='0oa2t0lsrdZw5uWRx297'
   OKTA_CLIENT_PASSWORD='HHduWG6LogIvDIQuWgp3Zlo9OYMValTtH5OBcuHw'
   ```
2. Set the `AUTH_FILE` variable. Replace `Z0000` with your contract number
   ```bash
   AUTH_FILE='credentials_Z0000.base64'
   ```
3. Create the AUTH token and write it to $AUTH_FILE
   ```bash
   echo -n "${OKTA_CLIENT_ID}:${OKTA_CLIENT_PASSWORD}" | base64 > $AUTH_FILE
   ```
4. Create a directory to store the job files and the results files and set the TARGET_DIR variable.   
   ```bash
   TODAYS_DATE=$(date '+%Y-%m-%d')
   mkdir -p $TODAYS_DATE && TARGET_DIR=./$TODAYS_DATE
   ```
5. Run a whole job including starting the job, monitoring the job, and downloading the requested files.
For production data change `-sandbox` to `-prod`.
   ```bash
   ./run-job.sh -sandbox --directory $TARGET_DIR --auth $AUTH_FILE --since 2020-02-13T00:00:00.000-05:00 --fhir R4 
   ```

### Running Scripts Individually

This is for developer debugging purpose.
1. Set the OKTA_CLIENT_ID and OKTA_CLIENT_PASSWORD. Replace values with your Client Id and Password.
   ```bash
   OKTA_CLIENT_ID='0oa2t0lsrdZw5uWRx297'
   OKTA_CLIENT_PASSWORD='HHduWG6LogIvDIQuWgp3Zlo9OYMValTtH5OBcuHw'
   ```
2. Set the `AUTH_FILE` variable. Replace `Z0000` with your contract number
   ```bash
   AUTH_FILE='credentials_Z0000.base64'
   ```
3. Create the AUTH token and write it to $AUTH_FILE
   ```bash
   echo -n "${OKTA_CLIENT_ID}:${OKTA_CLIENT_PASSWORD}" | base64 > $AUTH_FILE
   ```
4. Create a directory to store the job files and the results files and set the TARGET_DIR variable.
   ```bash
   TODAYS_DATE=$(date '+%Y-%m-%d')
   mkdir -p $TODAYS_DATE && TARGET_DIR=./$TODAYS_DATE
   ```
5. This sets environment variables used by the other scripts. Note bootstrap.sh does not work in zsh,
which is the default shell for Macs. To switch to bash, just type `bash` at the zsh prompt.
   ```bash
   source ./bootstrap.sh -sandbox --directory $TARGET_DIR --auth $AUTH_FILE --fhir R4 --since 2020-02-13T00:00:00.000-05:00
   ```
5. Run `./start-job.sh` to start a job. If successful a file containing
the job id will be saved in `<directory>/jobId.txt`
6. Run `./monitor-job.sh` which will monitor the state of the running job. When the job
finished the full HTTP response will be saved to `<directory>/response.json`
7. Run `./download-results.sh` to get the files. Running again will not overwrite the files
