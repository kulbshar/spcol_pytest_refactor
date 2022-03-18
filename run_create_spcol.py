#!/usr/local/apps/python/python3-controlled/bin/python -tt
"""
File: run_create_spcol.py

Creation Date: Dec2018

Primary client: Lab Programmers, Specimen Monitoring

Purpose : Calls create_spcol.sas create speicmen collection data sets
            from the various source CRF specimen collection datasets in qdata

Location: /trials/LabDataOps/managed_code/
            specimen_collection_dataset_creation/
"""
from datetime import date
import json
import subprocess
import sys
from pathlib import Path
from email.mime.text import MIMEText
import smtplib
import os
from json.decoder import JSONDecodeError
from typing import List, Tuple, Dict
import argparse

DEFAULT_CONFIG = os.path.join(
    Path(__file__).resolve().parent, "spcol_config.json"
)


class InvalidJSONError(Exception):
    pass


def read_json_config(config_json: str) -> Dict:
    """Read a JSON file path
    and return a dictionary config object.

    Args:
        config_json (str): path to file
    """

    with open(config_json) as cfg_json:
        try:
            config = json.load(cfg_json)
        except JSONDecodeError as e:
            raise InvalidJSONError(
                f"Error while decoding json file {config_json}\n {str(e)}"
            )
    return config


def run_sas_program(popen_arg_list: List) -> Tuple:
    """run SAS program to create SAS data sets

    Args:
        popen_arg_list: list of strings containing the SAS program call
        and arguments

    Returns tuple containing:
        sas_call_return_code (int): return from sas program call
        sas_call_std_out (str): return code description

    """

    sas_call = subprocess.Popen(popen_arg_list, stdout=subprocess.PIPE)

    # communicate() method must happen before getting returncode
    return_msg = sas_call.communicate()[0].decode()
    return_code = sas_call.returncode

    return (return_code, return_msg)


def send_status_email(
    email_to: str, email_from: str, email_subject: str, email_body: str
) -> None:
    """Send email with program output status

    Args:
        email_to (str): email to address
        email_from (str): email from address
        email_subject (str): subject of email
        email_body (str): body of email
    """

    msg = MIMEText(email_body)
    msg["Subject"] = email_subject
    msg["From"] = email_from
    msg["To"] = email_to

    with smtplib.SMTP("localhost") as s:
        s.sendmail(email_from, email_to, msg.as_string())


def get_parser() -> argparse.Namespace:
    """get command line arguments and return argparse.ArgumentParser"""
    my_parser = argparse.ArgumentParser(
        usage="./%(prog)s [-help] --config_path ./spcol_config.json",
        description="SPCOL Config",
    )

    my_parser.add_argument(
        "--config_path",
        type=str,
        help="the config file with create spcol sas program, emails and input & output directories params. Both absolute and relative paths are allowed.",
        required=False,
        default=DEFAULT_CONFIG,
    )

    args = my_parser.parse_args()
    return args


def main(config: Dict, log_mode: str = "replace") -> None:
    """Run SAS program to create specimen collection datasets by protocol

    Args:
        configuration dictionary containing:
            email_to (str): error notification to-email
            email_from (str): error notification from-email
            path_log (str): directory for SAS log output
            path_code (str): directory containing SAS code
            path_protocol_macros (str): directory containing SAS programs
                called on a per-protocol basis to modify spcol output
            path_protocol_config (str): directory containing protocol
                specimen configuration CSV files
            path_outdata (str): directory for output spcol SAS datasets
            path_fmtlib (str): directory containing SAS format catalog
            protocol_configs (dict): nested dictionary containing
                network containing a dictionary of protocols
                protocol containing a dictionary
                    parameters dictionary: parameters used by SAS program
                        call sysparm option
            log_mode (str): a value to the logparam parameter of SAS commandline
                            which tell SAS to replace or appends the log based on
                            whether it is REPLACE or APPEND
    """
    email_from = config["email_from"]
    email_to = config["email_to"]
    sas_program = config["sas_program"]
    path_code = config["path_code"]
    path_protocol_macros = config["path_protocol_macros"]
    path_protocol_config = config["path_protocol_config"]
    path_log = config["path_log"]
    path_outdata = config["path_outdata"]
    path_fmtlib = config["path_fmtlib"]
    prot_config = config["protocol_configs"]

    protocol_stat = {"successes": [], "failures": []}

    for net in prot_config:
        for prot in prot_config[net]:

            path_log_file = f"{path_log}spec_{net}_{prot}.log"

            params = ["network=" + net]
            params += ["protocol=" + prot]
            params += ["path_protocol_macros=" + path_protocol_macros]
            params += ["path_outdata=" + path_outdata]
            params += ["path_protocol_config=" + path_protocol_config]
            params += ["path_fmtlib=" + path_fmtlib]

            for param, value in prot_config[net][prot]["parameters"].items():
                params += [param + "=" + value]

            popen_list = ["sas_u8", "-noterminal", "-sysparm"]
            popen_list += [" ".join(params)]
            popen_list += [path_code + sas_program]
            popen_list += ["-log", path_log_file]
            popen_list += ["-logparm", f"open={log_mode}"]

            (sas_rc, sas_msg) = run_sas_program(popen_list)

            if sas_rc:
                protocol_stat["failures"] += [
                    f"{net} {prot}, see log: {path_log_file}"
                ]
            else:
                protocol_stat["successes"] += [f"{net} {prot}"]

    email_subject = "Specimen Collection Dataset Creation Status"
    email_body = "Specimen Collection Dataset Creation:\n"

    for state in protocol_stat:
        if state == "successes":
            email_body += "\nSuccessful Processing:\n"
            separator = ", "
        else:
            email_body += "\nProcessing failures:\n"
            separator = "\n\t"

        email_body += "\t" + separator.join(protocol_stat[state]) + "\n"

    if protocol_stat["failures"]:
        send_status_email(email_to, email_from, email_subject, email_body)


if __name__ == "__main__":
    args = get_parser()
    config = read_json_config(args.config_path)
    main(config)
