#!/bin/bash

#
# Variables ...
#
SHAPE="64GB"     # "8GB" "64GB" etc. 
DEPLOYMENT_NAME="sandbox_deployment"
API_URL="https://api.molecula.cloud/v1"
DATA_URL="https://data.molecula.cloud/v1"

#
# Dataset ...
#
S3_URL="https://se-public-datasets.s3.us-east-2.amazonaws.com/cseg0_backup.tar.gz"

#
# Table(s) and validation counts... set -A TABLE_NAMES "[table_name1]" "[table_name2]" etc.
#
set -A TABLE_NAMES "cseg" "skills" 
set -A TABLE_CNTS "1000000001" "25000"

##########################################
## Typically, no changes required below ##
##########################################

function deployment_delete {
   #
   # Parameters ...
   #
   API_URL=$1
   DEPLOYMENT_ID=$2
   DEPLOYMENT_NAME=$3

   #
   # Get Deployment Id ...
   #
   if [[ "${DEPLOYMNET_ID}" == "" ]];then
      STATUS=`curl -s --location --request GET "${API_URL}/deployments" --header "Authorization: ${TOKEN}" --header "Content-Type: text/plain"`
      #echo "${STATUS}"
      DEPLOYMENT_ID=`echo "${STATUS}" | jq -r ".resources[] | select(.name==\"${DEPLOYMENT_NAME}\") | .id"`
      echo "DEPLOYMENT_ID: ${DEPLOYMENT_ID}"
      if [[ "${DEPLOYMENT_ID}" == "" ]] || [[ "${DEPLOYMENT_ID}" == "null" ]];then
         echo "Deployment Name \"${DEPLOYMENT_NAME}\" does not exist, exiting ..."
         exit 1
      fi
   fi

   #
   # Delete all tables in Deployment ... 
   #
   STATUS=`curl -s --location --request GET "${API_URL}/tables/${DEPLOYMENT_ID}"  --header "Authorization: ${TOKEN}" --header "Content-Type: text/plain" | jq ".resources[]"`
   #echo "${STATUS}"
   while IFS= read -r p; do
      #echo $p
      TBL=`echo "${p}" | jq -r ".name"`
      if [[ "${TBL}" != "" ]] && [[ "${TBL}" != "null" ]]; then
         echo "Deleting TableName: ${DEPLOYMENT_ID}/${TBL}"
         DELSTATUS=`curl -s --location --request DELETE "${API_URL}/tables/${DEPLOYMENT_ID}/${TBL}"  --header "Authorization: ${TOKEN}" --header "Content-Type: text/plain" | jq "."`
         echo "${DELSTATUS}"
         sleep 10
      fi
   done < <(jq -r -c "." <<< ${STATUS})

   #
   # Delete Deployment ...
   #
   echo "Deleting Deployment ${DEPLOYMENT_NAME} id ${DEPLOYMENT_ID} ..."
   STATUS=`curl -s --location --request DELETE "${API_URL}/deployments/${DEPLOYMENT_ID}" \
    --header "Authorization: ${TOKEN}" \
    --header "Content-Type: application/json" | jq "."`
   echo "${STATUS}"

   # 
   # Status Loop ...
   #
   STATE="DELETING"
   while [[ "${STATE}" == "DELETING" ]];do
      STATUS=`curl -s --location --request GET "${API_URL}/deployments/${DEPLOYMENT_ID}" --header "Authorization: ${TOKEN}" --header "Content-Type: text/plain" | jq "."`
      STATE=`echo "${STATUS}" | jq -r ".deployment_status"`
      echo "${STATE}"
      sleep 10
   done
   if [[ "${STATE}" != "null" ]];then
      echo "${STATUS}"
      #echo "Error with Deleting Deployment, Exiting ..."
      #exit 1
   fi
   echo "Please verify that the deployment ${DEPLOYMENT_NAME} deleted and no other deployments exist..."
}  

#
# Requirements ... curl  
#
CURL=`which curl`
if [[ "${CURL}" == "" ]]; then
   echo "curl command is not installed or in the PATH environment variable, exiting. Please install curl and try again."
   exit 1
fi

#
# Get Username and Password ...
# 
echo "Welcome to Molecula Featurebase SaaS Trial!"
echo -n "Username: "; read USRNAME
stty -echo 
echo "Note: You will not see any characters or cursor movement when entering/pasting Password ..."
echo -n "Password: "; read -s PASSWD
stty echo
echo " "

#
# Authentication Token ...
#
TEXT=`curl -s --location --request POST "https://id.molecula.cloud" \
--header "Content-Type: application/json" \
--data-raw "{\"USERNAME\": \"${USRNAME}\",\"PASSWORD\": \"${PASSWD}\"}"` 
TOKEN=`echo "${TEXT}" | grep -Eo '"IdToken":.*?[^\\]",' | sed -e 's/[\"\,\: ]*//g' | sed -e 's/IdToken//'`
if [[ "${TOKEN}" == "" ]];then
   echo "${TEXT}"
   echo "Login Error, Exiting ..."
   exit 1
fi


#
# Create Deployment ...
#
STATUS=`curl -s --location --request POST "${API_URL}/deployments" \
 --header "Authorization: ${TOKEN}" \
 --header "Content-Type: application/json" \
 --data-raw "{
     \"name\": \"${DEPLOYMENT_NAME}\",
     \"deployment_options\": {\"shape\" : \"${SHAPE}\"}
}"`

DEPLOYMENT_ID=`echo "${STATUS}" | grep -Eo '"id":.*?[^\\]",' | sed -e 's/[\"\,\: ]*//g' | sed -e 's/id//'`
if [[ "${DEPLOYMENT_ID}" == "" ]]; then
   echo "Create Deployment API Result:${STATUS}"
   echo "Error with Creating Deployment, exiting. Please retry running script or contact us."
   exit 1
fi
echo "Creating your FeatureBase Deployment, this will take about one minute, please wait ..."

#
# Status Loop ...
#
STATE="CREATING"
while [[ "${STATE}" == "CREATING" ]];do
   STATUS=`curl -s --location --request GET "${API_URL}/deployments/${DEPLOYMENT_ID}" --header "Authorization: ${TOKEN}" --header "Content-Type: text/plain"`
   STATE=`echo "${STATUS}" | grep -Eo '"deployment_status":.*?[^\\]",' | sed -e 's/[\"\,\: ]*//g' | sed -e 's/deployment_status//'`
   echo "${STATE}"
   sleep 10
done
if [[ "${STATE}" != "RUNNING" ]];then
   echo "Deployment Status: ${STATE} ... API Result:${STATUS}"
   echo "Error with Creating Deployment, Exiting after cleanup. Please retry running script or contact us."
   deployment_delete "${API_URL}" "${DEPLOYMENT_ID}" "${DEPLOYMENT_NAME}"
   exit 1
fi
echo "Deployment ${DEPLOYMENT_NAME} successfully created and ${STATE}, proceeding with loading data into your deployment"
echo "This dataset has 1B records and takes about 30 minutes to restore, please wait ..."

#
# Restore Dataset from S3 bucket ...
#
STATUS=`curl -s --location --request PUT "${API_URL}/deployments/${DEPLOYMENT_ID}/action/restore" \
 --header "Authorization: ${TOKEN}" \
 --header "Content-Type: application/json" \
 --data-raw "{
   \"source_type\": \"http\",
   \"url\": \"${S3_URL}\"
}"`
echo "Restore API: ${STATUS}"

#
# Restore Status Loop ...
#
STATE="IN_PROGRESS"
while [[ "${STATE}" == "IN_PROGRESS" ]];do
   STATUS=`curl -s --location --request GET "${API_URL}/deployments/${DEPLOYMENT_ID}/action/restore" --header "Authorization: ${TOKEN}" --header "Content-Type: application/json"`
   STATE=`echo "${STATUS}" | grep -Eo '"status":.*?[^\\]",' | sed -e 's/[\"\,\: ]*//g' | sed -e 's/status//'`
   echo "${STATE}"
   sleep 10
done
if [[ "${STATE}" != "COMPLETED" ]];then
   echo "Restore Status: ${STATE} ... API Result: ${STATUS}"
   echo "Error with Restore, Deleting deploymnet before Exiting ..."
   deployment_delete "${API_URL}" "${DEPLOYMENT_ID}" "${DEPLOYMENT_NAME}" 
   exit 1
fi
echo "Restore successful and ${STATE}, proceeding with Table(s) creation"

#
# Create Table(s) after Restore is Completed ...
#
for x in ${TABLE_NAMES[@]};do
   STATUS=`curl -s --location --request POST "${API_URL}/tables/${DEPLOYMENT_ID}/" \
 --header "Authorization: ${TOKEN}" --header "Content-Type: text/plain" \
 --data-raw "{\"name\": \"${x}\", \"description\": \"Table containing fabricated customer data to highlight low latency segmentation\"}"`
   echo "Create Table ${x} API: ${STATUS}"
done

#
# Query Count Validation...
#
TABLE_NUM=1
for item in ${TABLE_NAMES}
do
   echo "Validate Record Count Table: ${TABLE_NAMES[$TABLE_NUM]}"

   PQL="[${TABLE_NAMES[$TABLE_NUM]}]Count(All())"
   echo "PQL> ${PQL}"
   STATUS=`curl -s --location --request POST "${DATA_URL}/deployments/${DEPLOYMENT_ID}/query" \
   --header "Authorization: ${TOKEN}" \
   --header "Content-Type: application/vnd.molecula.pql" \
   --data-raw "{ \"language\": \"pql\", \"statement\": \"${PQL}\"}"`
   CNT=`echo "${STATUS}" | grep -Eo '"Uint64Val":(\d*?,|.*?[^\\]})' | sed -e "s/\"Uint64Val\"://" | sed -e "s/}//"`
   echo "Record Count: ${CNT}"

   if [[ "${CNT}" != ${TABLE_CNTS[$TABLE_NUM]} ]];then
      echo "${TABLE_NAMES[$TABLE_NUM]} records were not loaded succesfully, exiting. Please retry running script or contact us."
      deployment_delete "${API_URL}" "${DEPLOYMENT_ID}" "${DEPLOYMENT_NAME}" 
      exit 1
   fi

   SQL="select count(*) from ${TABLE_NAMES[$TABLE_NUM]}"
   echo "SQL> ${SQL}"
   STATUS=`curl -s --location --request POST "${DATA_URL}/deployments/${DEPLOYMENT_ID}/query" \
   --header "Authorization: ${TOKEN}" \
   --header "Content-Type: application/vnd.molecula.sql" \
   --data-raw "{ \"language\": \"sql\", \"statement\": \"${SQL}\"}"`
   CNT=`echo "${STATUS}" | grep -Eo '"Uint64Val":(\d*?,|.*?[^\\]})' | sed -e "s/\"Uint64Val\"://" | sed -e "s/}//"`
   echo "Record Count: ${CNT}"

   if [[ "${CNT}" != ${TABLE_CNTS[$TABLE_NUM]} ]];then
      echo "${TABLE_CNTS[$TABLE_NUM]} records were not loaded succesfully, exiting. Please retry running script or contact us."
      deployment_delete "${API_URL}" "${DEPLOYMENT_ID}" "${DEPLOYMENT_NAME}" 
      exit 1
   fi

   TABLE_NUM=$((TABLE_NUM+1))
done

echo "Process Completed! Please naviagate to https://app.molecula.cloud/ in your browser to explore the data!"

