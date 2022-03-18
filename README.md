# Specimen Collection Dataset Creation

## Overview
This is a project that creates the specimen collection SAS datasets for
Rave-datamart studies.

Program "run_create_spcol.py" is scheduled on CRONSRV crontab
This python script

    1. identifies available configuration files in the configuration
    path listed below
    2. run the SAS program create_spcol.sas for each network-protocol
    3. outputs SAS data sets in the production datasets path listed below

### File Paths
Programs: `/trials/LabDataOps/managed_code/specimen_collection_dataset_creation/`
Logs: `/trials/LabDataOps/common/logs/specimen_collection_dataset_creation`
Configuration files: `/trials/LabDataOps/managed_code/specimen_collection_dataset_creation/protocol_specimen_config/`
Production datasets: `/trials/lab/data/spec/`

### NOTE: This LDP code is used for newer protocols
Some older protocols have specimen collection data sets created by
clinprog. This code is stored in the protocol study direcotry:
/trials/vaccine/p107/s617/code/update_spec_v107.sas

## Usage
run_create_spocl.py is intended to be run without parameters:
`./run_create_spcoly.py`

## Testing operation in devel
1. Make and check out a branch to your devel
2. Update test_rcreate_spcol.py
    a. Changes for email, paths do not have to be comitted, while
    changes for additional networks/protocols should be committed
    b. Update values in CONFIG_DICT such as emails and paths
3. update test_spcol_config.json 
    a. Changes for network(s)/protocol(s) for which you are
       interested to create spcol output dataset for the test.
    b. the output dataset spec_{network}_{protocol}.sas7bdat 
       will get created at 
       /scharp/devel/testing/ldo_testing/test_create_spcol/output/
    c. reveiw this output or sometimes you may need to provide this 
       output dataset to be reviewed by LDM.
4. run `python -m pytest test_create_spcol.py`
5. confirm outputs in directories specified in the CONFIG_DICT

## Author(s)
* **LDP**: Thomas D - tdonn@scharp.org, Kulbhushan S - ksharma@scharp.org