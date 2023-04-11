#!/bin/bash

set -eEu -o pipefail +x
EXCLUDE_MAIN_REGION=''

get_aws_regions() {
  local aws_regions=$(aws ec2 describe-regions \
    --filters '[{"Name": "opt-in-status", "Values": ["opted-in","opt-in-not-required"]}]' \
    --query "Regions[*] | sort_by(@, &RegionName)[*].{RegionName: RegionName}" \
    --output text)
  echo "${aws_regions}"
}

delete_subnets() {
  local aws_region="$1"
  local vpc_id="$2"
  local subnet_ids=$(aws ec2 describe-subnets --region "${aws_region}" \
                  --filters Name=vpc-id,Values=${vpc_id} \
                  --query "Subnets[].SubnetId" \
                  --output text)
  for subnet_id in ${subnet_ids}; do
    echo "Deleting subnet with id ${subnet_id}"
    aws ec2 delete-subnet --region "${aws_region}" \
      --subnet-id "${subnet_id}"
  done
}

delete_routes() {
  local aws_region="$1"
  local vpc_id="$2"
  local route_ids=$(aws ec2 describe-route-tables --region "${aws_region}" \
                  --filters Name=vpc-id,Values=${vpc_id} \
                  --query "RouteTables[].RouteTableId" \
                  --output text)
  for route_id in ${route_ids}; do
    echo "Deleting route table with id ${route_id}"
    aws ec2 delete-route-table --region "${aws_region}" \
      --route-table-id "${route_id}"
  done
}

delete_route_tables() {
  local aws_region="$1"
  local vpc_id="$2"
  local route_table_ids=$(aws ec2 describe-route-tables --region "${aws_region}" \
                  --filters Name=vpc-id,Values=${vpc_id} \
                  --query "RouteTables[].RouteTableId" \
                  --output text)
  for route_table_id in ${route_table_ids}; do
    echo "Deleting route table with id ${route_table_id}"
    aws ec2 delete-route-table --region "${aws_region}" \
      --route-table-id "${route_table_id}"
  done
}

delete_internet_gateways() {
  local aws_region="$1"
  local vpc_id="$2"
  local internet_gateway_ids=$(aws ec2 describe-internet-gateways --region "${aws_region}" \
                  --filters Name=attachment.vpc-id,Values=${vpc_id} \
                  --query "InternetGateways[].InternetGatewayId" \
                  --output text)
  for internet_gateway_id in ${internet_gateway_ids}; do
    echo "Deleting internet gateway with id ${internet_gateway_id}"
    aws ec2 --region ${aws_region} \
      detach-internet-gateway --internet-gateway-id ${internet_gateway_id} --vpc-id ${vpc_id}
    aws ec2 --region "${aws_region}" \
      delete-internet-gateway --internet-gateway-id "${internet_gateway_id}"
  done
}

delete_network_acls() {
  local aws_region="$1"
  local vpc_id="$2"
  local network_acl_ids=$(aws ec2 describe-network-acls --region "${aws_region}" \
                  --filters Name=vpc-id,Values=${vpc_id} \
                  --query "NetworkAcls[].NetworkAclId" \
                  --output text)
  for network_acl_id in ${network_acl_ids}; do
    echo "Deleting network ACL with id ${network_acl_id}"
    aws ec2 delete-network-acl --region "${aws_region}" \
      --network-acl-id "${network_acl_id}"
  done
}

delete_security_groups() {
  local aws_region="$1"
  local vpc_id="$2"
  local security_group_ids=$(aws ec2 describe-security-groups --region "${aws_region}" \
                  --filters Name=vpc-id,Values=${vpc_id} \
                  --query "SecurityGroups[].GroupId" \
                  --output text)
  for security_group_id in ${security_group_ids}; do
    echo "Deleting security group with id ${security_group_id}"
    aws ec2 --region "${aws_region}" \
      delete-security-group --group-id "${security_group_id}"
  done
}

delete_resources() {
  local aws_region="$1"
  local region_vpc_ids=$(aws ec2 describe-vpcs --region "${aws_region}" --query "Vpcs[?IsDefault].VpcId" --output text)
  local vpc_count=$(echo "${region_vpc_ids}" | wc -l)
  if [ "${vpc_count}" != "0" ]; then
    for vpc_id in ${region_vpc_ids}; do
      echo "Deleting subnets in VPC_ID ${vpc_id} in region ${aws_region}"
      delete_subnets "${aws_region}" "${vpc_id}"
      echo "Deleting internet gateways in VPC_ID ${vpc_id} in region ${aws_region}"
      delete_internet_gateways "${aws_region}" "${vpc_id}"
      # Turns out the default route table, default network ACL, and default SG
      # will be deleted automatically when the VPC is deleted.
      # No need to try to delete those defaults manually.
      # echo "Deleting route tables in VPC_ID ${vpc_id} in region ${aws_region}"
      # delete_route_tables "${aws_region}" "${vpc_id}"
      # echo "Deleting network ACLs in VPC_ID ${vpc_id} in region ${aws_region}"
      # delete_network_acls "${aws_region}" "${vpc_id}"
      # echo "Deleting security groups in VPC_ID ${vpc_id} in region ${aws_region}"
      # delete_security_groups "${aws_region}" "${vpc_id}"

      echo "Deleting VPC ${vpc_id} in region ${aws_region}"
      aws ec2 delete-vpc --region "${aws_region}" --vpc-id "${vpc_id}"
    done
  fi
}

delete_defaults() {
  local aws_regions=$(get_aws_regions)
  echo "EXCLUDE_MAIN_REGION = ${EXCLUDE_MAIN_REGION}"
  echo "Will delete default network resources in the following AWS regions:"
  for aws_region in ${aws_regions}; do
    if [[ "${EXCLUDE_MAIN_REGION}" != "" && "${aws_region}" == "${EXCLUDE_MAIN_REGION}" ]]; then
      continue
    else
      echo "  - ${aws_region}"
    fi
  done

  for aws_region in ${aws_regions}; do
    if [[ "${EXCLUDE_MAIN_REGION}" != "" && "${aws_region}" == "${EXCLUDE_MAIN_REGION}" ]]; then
      continue
    else
      echo "Deleting default resources in ${aws_region}"
      delete_resources "${aws_region}"
    fi
  done
}

main() {
  if [ ${#} -gt 0 ]; then
    EXCLUDE_MAIN_REGION=$1
  fi
  delete_defaults 
}

main "$@"
