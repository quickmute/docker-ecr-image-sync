#!/bin/sh
# Get Account from metadata
ACCOUNT=`curl -Ss http://169.254.169.254/latest/dynamic/instance-identity/document|grep accountId| awk '{print $3}'|sed  's/"//g'|sed 's/,//g'`
# Get Region from metadata
REGION=`curl -Ss http://169.254.169.254/latest/meta-data/placement/availability-zone | awk '{print substr($1, 1, length($1)-1)}'`
# Grab first 3 columns and ignore first row (header)
OUTPUT=`docker image list | awk '{if (NR!=1) {print $1,$2,$3}}'`
# Save the current IFS
OLDIFS=$IFS
#Set new IFS
#Enter literal carraige return here
IFS='
'
#Set break flag (didn't end up using it)
BREAKFLAG=0
echo $REGION
#Login
LOGIN=`aws ecr get-login-password --region $REGION | docker login -u AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com`
if [ "$LOGIN" = "Login Succeeded" ]; then
        echo "Login Succeeded"
else
        echo "Error during login"
        BREAKFLAG=1
        break
fi
#Iterate through all images
for LINE in $OUTPUT
do
        # set IFS to spaces
        IFS=' '
        # Different column means different data to collect
        COUNTER=0
        for ITEM in $LINE
        do
                #Populate variable with information about docker image
                case $COUNTER in
                        0) NAME=$ITEM;;
                        1) TAG=$ITEM;;
                        2) ID=$ITEM;;
                esac
                COUNTER=$(($COUNTER + 1))
        done
        #Need to lookup if ECR repo with this name exists yet?
        REPOCHECK=`aws ecr describe-repositories --repository-names $NAME --region $REGION`
        if [ $? -eq 0 ]; then
                echo "$NAME repo exists"
        else
                # if it doesn't exist, then go ahead and create it
                echo "$NAME repo does not exists"
                REPOCREATE=`aws ecr create-repository --repository-name $NAME --region $REGION`
                if [ $? -eq 0 ]; then
                        echo "New Repo created"
                else
                        echo "Error during creating repo $NAME"
                        BREAKFLAG=1
                        break
                fi
        fi
        #TAG it
        REPOTAG=`docker tag $NAME:$TAG $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$NAME:$TAG`
        if [ $? -eq 0 ]; then
                echo "Tagged $NAME to go to ECR"
        else
                echo "Error while tagging"
                BREAKFLAG=1
                break
        fi
        #Push it
        REPOPUSH=`docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$NAME:$TAG`
        if [ $? -eq 0 ]; then
                echo "Pushed the $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$NAME:$TAG"
        else
                echo "Error while pushing $NAME:$TAG"
                BREAKFLAG=1
                break
        fi
        #Delete it
        IMAGEDELETE=`docker image rm $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$NAME:$TAG`
        if [ $? -eq 0 ]; then
                echo "Removed $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$NAME:$TAG"
        else
                echo "Failed to remove $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$NAME:$TAG"
        fi
done
echo "Done"
IFS=$OLDIFS
