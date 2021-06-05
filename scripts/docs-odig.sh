image=tezos:odig
source_path=/home/opam/_opam/var/cache/odig/html/
destination_path=./odig/html

mkdir -p $destination_path
docker build --pull --rm -f "odig.Dockerfile" -t $image "."

container_id=$(docker create $image)  # returns container ID
docker cp  --follow-link $container_id:$source_path $destination_path
docker rm $container_id
