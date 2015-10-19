if [ -z "$AUTH_TOKEN" ]; then
  AUTH_TOKEN=`cat /var/run/secrets/kubernetes.io/serviceaccount/token`
fi

if [ -e /run/secrets/kubernetes.io/serviceaccount/ca.crt ]; then
  alias oc="oc -n $PROJECT --token=$AUTH_TOKEN --server=$OPENSHIFT_API_URL --certificate-authority=/run/secrets/kubernetes.io/serviceaccount/ca.crt "
else
  alias oc="oc -n $PROJECT --token=$AUTH_TOKEN --server=$OPENSHIFT_API_URL --insecure-skip-tls-verify "
fi

TEMPLATE_IMAGE=`oc get rc ${RELEASE_FROM_RC} -t '{{$a:= index .spec.template.spec.containers 0 }}{{$a.image}}'`

echo "*******"
echo "Creating REL-$RELEASE_NUMBER from Image $TEMPLATE_IMAGE"
echo "*******"

oc new-app --template=php3tier-release --param=APP_RELEASE=rel-$RELEASE_NUMBER --param=APP_IMAGE=$TEMPLATE_IMAGE

SERVICE="rel-$RELEASE_NUMBER-simplephp"
TEST_ENDPOINT=`oc get service ${SERVICE} -t '{{.spec.clusterIP}}{{":"}}{{ $a:= index .spec.ports 0 }}{{$a.port}}'`

echo "Checking for successful test deployment at $TEST_ENDPOINT"
set +e
rc=1
count=0
attempts=100
while [ $rc -ne 0 -a $count -lt $attempts ]; do
  if curl -s --connect-timeout 2 $TEST_ENDPOINT >& /dev/null; then
    rc=0
    break
  fi
  count=$(($count+1))
  echo "Attempt $count/$attempts"
  sleep 5
done
set -e

if [ $rc -ne 0 ]; then
    echo "Failed to access release deployment, aborting roll out."
    exit 1
fi

#Expose Service, creating Pulic URL via Route
oc expose service $SERVICE
