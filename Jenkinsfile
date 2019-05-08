pipeline {
  agent {
    kubernetes {
      label 'blog.ju.ma'
      yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: blog
    image: alpine
    command: ['cat']
    tty: true
    envFrom:
    - secretRef:
        name: s3-blog-storage
"""
    }
  }

  environment {
      HUGO_VERSION = "0.55.5"
  }

  stages {
    stage('Deploy Blog') {
      steps {
        container('blog') {
          sh """ apk --no-cache add \
                ca-certificates \
                curl \
                tar \
                py-pip \
                tree \
                && pip install s3cmd
          """
          sh "[ ! -f ./hugo ] && curl -sSL https://github.com/gohugoio/hugo/releases/download/v${env.HUGO_VERSION}/hugo_${env.HUGO_VERSION}_Linux-64bit.tar.gz | tar -v -C ./ hugo -xz"
          sh """{ \
            echo '[default]'; \
            echo 'access_key=\$S3_ACCESS_KEY_ID'; \
            echo 'secret_key=\$S3_SECRET_ACCESS_KEY'; \
            } > ~/.s3cfg
          """

          sh "rm -rf ./public && ./hugo"
          sh "cd ./public; tree ./; s3cmd sync --delete-removed -P . s3://blog.ju.ma/"
        }
      }
    }
  }
}