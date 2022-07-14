# Prerequisites

Setup required services and infrastructure:
```
terraform -chdir=tf init
terraform -chdir=tf apply
```

## Container

Working with the container locally:

```
cd docker
sudo podman build -t php-nfs .
sudo podman run -p 8080:80 localhost/php-nfs
```

## Cloud Run

We need to know the firestore IP:
```
gcloud filestore instances describe my-filestore --project nvoss-php-nfs-demo --zone europe-west1-d --format "value(networks.ipAddresses[0])"
```

Then we can simply deploy our application (connection will go through our VPC connector):
```
gcloud beta run deploy filesystem-app --source . \
    --vpc-connector my-vpc-con \
    --execution-environment gen2 \
    --allow-unauthenticated \
    --project nvoss-php-nfs-demo \
    --region europe-west1 \
    --port 80 \
    --update-env-vars FILESTORE_IP_ADDRESS=10.39.55.66,FILE_SHARE_NAME=data
```

First time might result in:
```
Deploying from source requires an Artifact Registry Docker repository to store built containers. A repository named
[cloud-run-source-deploy] in region [europe-west1] will be created.

Do you want to continue (Y/n)?  Y
```

We can not interact directly with Firestore, so we'll need a VM to interact with the NFS:
```
# We can SSH without a public IP via IAP
gcloud compute ssh --zone "europe-west1-b" "myvm"  --tunnel-through-iap --project "nvoss-php-nfs-demo"
# We can SCP files via IAP
gcloud compute scp index.php root@myvm:/tmp --project=nvoss-php-nfs-demo --zone=europe-west1-b
```

Due to organization policies I can't make the application public, but we can test it as follows:
```
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" https://filesystem-app-wawokuzksa-ew.a.run.app/
```

## GKE Autopilot

Cluster was setup before, so we only have to deploy:

We can watch how it happens in a second terminal as well:
```
watch kubectl get po,pvc,pv
```
Then simply apply the manifests:
```
kubectl apply -f manifests.yaml
```
We can forward the port:
```
kubectl port-forward app-7dd4f455db-q88mx 8080:80
```
Or execute commands in the container:
```
kubectl exec -it app-7dd4f455db-hk2qm -c app -- bash
```
And get the logs (also through GCP console):
```
kubectl logs app-7dd4f455db-q88mx
```
