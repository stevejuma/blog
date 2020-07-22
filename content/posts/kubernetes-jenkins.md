---
title: Kubernetes Jenkins
date: 2019-05-04T17:46:33+01:00
draft: false
description: Jenkins with kubernetes
---
There are alot of documents on the web on how to setup Kubernetes and 
even more on how to run a Jenkins instance. I have however been unable
to find a comprehensive enough guide on how to do both, especially on 
an on-prem Kubernetes install. The rage currently seems to be on running
`Jenkins X`, but my previous attempts at trying to get it to work weren't 
successsful, will probably be the subject of another blog post. 

```bash
# Create a namespace to hold your configuration
kubectl create namespace ci
# Create credentials for any private registries
kubectl create -n ci secret docker-registry regcred \
    --docker-server=<your-registry-server> \
    --docker-username=<your-name> \
    --docker-password=<your-pword> \
    --docker-email=<your-email>
# Or if you are using gcr
kubectl create -n ci secret docker-registry gcr-regcred \
    --docker-server=eu.gcr.io \
    --docker-username=_json_key \
    --docker-password="$(cat /path/to/gcr-account.json)" \
    --docker-email=my@email.com
```

Create a service account for Jenkins that will provide credentials required for
the Kubernetes Plugin. 

```yaml
# jenkins-service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins
  namespace: ci
  labels:
    app: jenkins
automountServiceAccountToken: true
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: Jenkins-cluster-admin
  namespace: ci
  labels:
    app: jenkins
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: jenkins
    namespace: ci
```

Create an image with `kubectl` that will be used as an init container for the
Jenkins deployment. 

```bash
# kubectl.yaml
FROM alpine

ARG kubectl_version=v1.13.1

RUN apk add --update ca-certificates \
 && apk add --update -t deps curl \
 && curl -L https://storage.googleapis.com/kubernetes-release/release/${kubectl_version}/bin/linux/amd64/kubectl -o /usr/local/bin/kubectl \
 && chmod +x /usr/local/bin/kubectl \
 && apk del --purge deps \
 && rm /var/cache/apk/*

WORKDIR /root
ENTRYPOINT ["kubectl"]
```


Finally create the Jenkins deployment, complete with ingress and init container.

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: jenkins-pvc
  namespace: ci
  labels:
    app: jenkins
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kubectl-jenkins-context
  namespace: ci
  labels:
    app: jenkins
data:
  kubectl-config-context.sh: |-
    #!/bin/bash -v

    kubectl config set-credentials jenkins --token=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
    kubectl config set-cluster jenkinscluster --server="https://kubernetes.default.svc:443" --certificate-authority="/var/run/secrets/kubernetes.io/serviceaccount/ca.crt"
    kubectl config set-context jenkins-context --cluster=jenkinscluster --user=jenkins --namespace=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
    kubectl config use-context jenkins-context
    chmod 755 ~/.kube/config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: ci
  labels:
    app: jenkins
    version: v1
spec:
  selector:
    matchLabels:
      app: jenkins
  strategy:
    type: Recreate
  template:
    metadata:
      namespace: ci
      labels:
        app: jenkins
    spec:
      serviceAccountName: jenkins
      initContainers:
        - image: <registry-url>/kubectl:1.13.1
          name: kubectl-config
          command:
            - "/bin/sh"
          args:
            - "/kubectl-config-context.sh"
          volumeMounts:
            - name: kubeconfig
              mountPath: "/root/.kube"
            - name: kubectl-jenkins-context
              mountPath: "/kubectl-config-context.sh"
              subPath: "kubectl-config-context.sh"
      containers:
        - image: jenkins/jenkins:lts-slim
          name: jenkins
          volumeMounts:
            - name: kubeconfig
              mountPath: /var/jenkins_home/.kube
            - name: jenkins-persistent-storage
              mountPath: /var/jenkins_home
          ports:
            - containerPort: 8080
              name: http-port
            - containerPort: 50000
              name: jnlp-port
          imagePullPolicy: Always
      securityContext:
        fsGroup: 1000
      imagePullSecrets:
        - name: regcred
      # If you are using gcr  
      # - name: gcr-regcred
      volumes:
        - name: kubectl-jenkins-context
          configMap:
            name: kubectl-jenkins-context
            items:
              - key: kubectl-config-context.sh
                path: kubectl-config-context.sh
        - name: kubeconfig
          emptyDir: {}
        - name: jenkins-persistent-storage
          persistentVolumeClaim:
            claimName: jenkins-pvc
```

Create a service for the Jenkins deployment.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jenkins
  namespace: ci
spec:
  selector:
    app: jenkins
  ports:
    - port: 8080
      targetPort: 8080
      name: http
    - port: 50000
      targetPort: 50000
      name: jnlp
```

Finally create an ingress resource if you need one. This assumes you have cert-manager
deployed in the cluster for issuing certificates

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: ci
  labels:
    app: jenkins
  annotations:
    kubernetes.io/ingress.class: nginx
    certmanager.k8s.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - jenkins.domain.com
      secretName: jenkins-tls-cert
  rules:
    - host: jenkins.domain.com
      http:
        paths:
          - backend:
              serviceName: jenkins
              servicePort: http
```
