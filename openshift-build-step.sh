if [ -z "$AUTH_TOKEN" ]; then
  AUTH_TOKEN=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`
fi

if [ -e /run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
  alias oc="oc -n $PROJECT --token=$AUTH_TOKEN --server=$OPENSHIFT_API_URL --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt "
else 
  alias oc="oc -n $PROJECT --token=$AUTH_TOKEN --server=$OPENSHIFT_API_URL --insecure-skip-tls-verify "
fi

echo "Triggering new application build and deployment"
OSE_BUILD_ID=`oc start-build ${BUILD_CONFIG}`

# stream the logs for the build that just started
rc=1
count=0
attempts=3
set +e
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  oc build-logs $OSE_BUILD_ID
  rc=$?
  count=$(($count+1))
done
set -e

echo "Checking build result status"
rc=1
count=0
attempts=100
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  status=`oc get build ${OSE_BUILD_ID} -t '{{.status.phase}}'`
  if [[ $status == "Failed" || $status == "Error" || $status == "Canceled" ]]; then
    echo "Fail: Build completed with unsuccessful status: ${status}"
    exit 1
  fi

  if [ $status == "Complete" ]; then
    echo "Build completed successfully, will test deployment next"
    rc=0
  else 
    count=$(($count+1))
    echo "Attempt $count/$attempts"
    sleep 5
  fi
done

if [ $rc -ne 0 ]; then
    echo "Fail: Build did not complete in a reasonable period of time"
    exit 1
fi

#status=`oc deploy ${DEPLOYMENT_CONFIG} --latest`
status=`oc deploy ${DEPLOYMENT_CONFIG} `


echo $status
