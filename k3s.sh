
get_status() {
    docker inspect k3s_server_1 --format='{{ .State.Status }}' 2> /dev/null
}

has_volume() {
    docker volume ls | grep k3s_k3s-server 2>&1 > /dev/null
}

start() {
    status=$(get_status)
    if [[ "$status" == "exited" ]]; then
        echo "Stopped"
        docker-compose start
    elif [[ "$status" == "running" ]]; then
        echo "Running"
    else
        echo "Unavailable"
        rm -f kubeconfig.yaml ~/.kube/config.k3s
        docker-compose up -d --scale agent=3
	echo "Waiting for kubeconfig.yaml to be created . . ."
	while ! test -f "kubeconfig.yaml"; do
	    sleep 1
	done
        cp kubeconfig.yaml ~/.kube/config.k3s
	chmod 600 ~/.kube/config.k3s
	echo "Done"
    fi
}

clean() {
    for node in `kubectl get node | grep NotReady | awk '{print $1}'`; do
        echo "Remove node $node"
        kubectl delete node $node
    done
}

if [ ! -f token ]; then
    echo -n ${RANDOM}${RANDOM}${RANDOM} > token
fi

if [ ! -f docker-compose.yaml ]; then
    curl -Ls https://raw.githubusercontent.com/k3s-io/k3s/master/docker-compose.yml \
        | sed -e 's/command: server/command: server --no-deploy traefik/' \
        | sed -e 's/restart: always/restart: "no"/g' \
        > docker-compose.yml
fi

export K3S_TOKEN=$(cat token)
export KUBECONFIG=./kubeconfig.yaml

case "$1" in
"stop")
    docker-compose stop
    ;;
"reset")
    docker-compose down -v
    rm -rf token kubeconfig.yaml docker-compose.yml
    ;;
"rm")
    docker-compose rm -s -v
    ;;
"clean")
    clean
    ;;
*)
    start
    ;;
esac

