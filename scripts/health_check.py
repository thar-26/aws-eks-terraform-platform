#!/usr/bin/env python3
"""Health check for the dev EKS platform.

Checks:
  1. EKS cluster status is ACTIVE
  2. Every managed node group is ACTIVE
  3. No CloudWatch alarms with the given prefix are in ALARM state

Exit code 0 = healthy, 1 = at least one check failed.

Usage:
  python scripts/health_check.py
  python scripts/health_check.py --cluster dev-eks --prefix dev --region eu-north-1
"""
import argparse
import sys

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def check_cluster(eks, cluster):
    try:
        status = eks.describe_cluster(name=cluster)["cluster"]["status"]
    except ClientError as err:
        code = err.response["Error"]["Code"]
        if code == "ResourceNotFoundException":
            return False, f"cluster '{cluster}' not found"
        return False, f"AWS error: {code}"
    return status == "ACTIVE", f"status={status}"


def check_nodegroups(eks, cluster):
    try:
        names = eks.list_nodegroups(clusterName=cluster)["nodegroups"]
    except ClientError as err:
        return False, f"AWS error: {err.response['Error']['Code']}"
    if not names:
        return False, "no node groups found"
    bad = []
    for name in names:
        ng = eks.describe_nodegroup(clusterName=cluster, nodegroupName=name)["nodegroup"]
        if ng["status"] != "ACTIVE":
            bad.append(f"{name}={ng['status']}")
    if bad:
        return False, ", ".join(bad)
    return True, f"{len(names)} node group(s) ACTIVE"


def check_alarms(cloudwatch, prefix):
    firing = []
    paginator = cloudwatch.get_paginator("describe_alarms")
    for page in paginator.paginate(AlarmNamePrefix=prefix, StateValue="ALARM"):
        firing += [a["AlarmName"] for a in page["MetricAlarms"]]
    if firing:
        return False, "in ALARM: " + ", ".join(firing)
    return True, "no alarms firing"


def main():
    parser = argparse.ArgumentParser(description="Health check for the EKS platform")
    parser.add_argument("--region", default="eu-north-1")
    parser.add_argument("--cluster", default="dev-eks")
    parser.add_argument("--prefix", default="dev", help="CloudWatch alarm name prefix")
    args = parser.parse_args()

    try:
        session = boto3.Session(region_name=args.region)
        eks = session.client("eks")
        cloudwatch = session.client("cloudwatch")
        results = [
            ("EKS cluster", *check_cluster(eks, args.cluster)),
            ("Node groups", *check_nodegroups(eks, args.cluster)),
            ("CloudWatch alarms", *check_alarms(cloudwatch, args.prefix)),
        ]
    except (BotoCoreError, ClientError) as err:
        print(f"ERROR: could not run checks: {err}")
        return 1

    failed = False
    for name, ok, detail in results:
        print(f"[{'OK' if ok else 'FAIL'}] {name}: {detail}")
        failed = failed or not ok
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
