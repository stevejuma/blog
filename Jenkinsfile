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
    image: stevejuma/hugo:0.62.1
    command: ['cat']
    tty: true
    envFrom:
    - secretRef:
        name: s3-blog-storage
"""
    }
  }

  options {
    buildDiscarder(logRotator(numToKeepStr: '5'))
  }

  environment {
      HUGO_VERSION = "0.62.1"
  }

  stages {
    stage('Deploy Blog') {
      steps {
        container('blog') {
          sh """{ \
            echo '[default]'; \
            echo 'access_key=\$S3_ACCESS_KEY_ID'; \
            echo 'secret_key=\$S3_SECRET_ACCESS_KEY'; \
            } > ~/.s3cfg
          """

          sh "rm -rf ./public && hugo"
          sh "[ -d ./public ] && cd public && s3cmd sync --delete-removed -P . s3://blog.ju.ma/"
        }
      }
    }
  }
}
