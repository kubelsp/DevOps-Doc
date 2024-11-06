### 1、ruoyi-gateway-pipeline

```shell
# 参数化构建
AppName
服务名称
ruoyi-gateway

GitRepo
代码仓库
http://gitlab.huanghuanhui.cloud/root/RuoYi-Cloud.git

GitBranch
master
代码分支

HarborUrl
镜像仓库地址
harbor.huanghuanhui.cloud

Image
基础镜像
ccr.ccs.tencentyun.com/huanghuanhui/openjdk:8-jre

JAVA_OPTS
jar 运行时的参数配置
-Xms1024M -Xmx1024M -Xmn256M -Dspring.config.location=app.yml -Dserver.tomcat.max-threads=800
```

```shell
#!/usr/bin/env groovy

def git_auth = "77066368-e8a8-4edb-afaf-53aaf90c31a9"
def harbor_auth = "9c10572f-c324-422f-b0c0-1b80d2ddb857"
def kubectl_auth = "c26898c2-92c3-4c19-8490-9cf8ff7918ef"

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  name: jenkins-slave
  namespace: jenkins-prod
spec:
  tolerations:
  - key: "no-pod"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: docker
    #image: docker:24.0.6
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6
    imagePullPolicy: IfNotPresent
    readinessProbe:
      exec:
        command: [sh, -c, "ls -S /var/run/docker.sock"]
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: docker-daemon
    #image: docker:24.0.6-dind
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6-dind
    imagePullPolicy: IfNotPresent
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: maven
    #image: maven:3.8.1-jdk-8
    image: ccr.ccs.tencentyun.com/huanghuanhui/maven:3.8.1-jdk-8
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2/repository
  - name: kubectl
    image: kostiscodefresh/kubectl-argo-rollouts:v1.6.0
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
  volumes:
  - name: docker-socket
    emptyDir: {}
  - name: maven-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-maven-cache
  - name: node-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-node-cache
'''
        }
    }

environment {
AppName = "${AppName}"
GitRepo = "${GitRepo}"
GitBranch = "${GitBranch}"
HarborUrl = "${HarborUrl}"
Image = "${Image}"
JAVA_OPTS = "${JAVA_OPTS}"
}

    stages {
        stage('拉取代码') {
			steps {
			git branch: "${GitBranch}", credentialsId: "${git_auth}", url: "${GitRepo}"
			}
		}

        stage('代码编译') {
            steps {
              container('maven') {
                sh """
                  mvn -U clean install -Dmaven.test.skip=true
                """
                }
            }
        }

        stage('打包镜像') {
            steps {
              script {env.GIT_COMMIT_MSG = sh (script: 'git rev-parse --short HEAD', returnStdout: true).trim()}
              container('docker') {
sh '''cat > entrypoint.sh << EOF
#! /bash/bin -e
env
java $JAVA_OPTS -jar ./*.jar
EOF

cat > app.yml << EOF
# Tomcat
server:
  port: 8080

# Spring
spring:
  application:
    # 应用名称
    name: ${AppName}
  profiles:
    # 环境配置
    active: dev
  cloud:
    nacos:
      discovery:
        # 服务注册地址
        server-addr: nacos-headless.nacos.svc.cluster.local:8848
      config:
        # 配置中心地址
        server-addr: nacos-headless.nacos.svc.cluster.local:8848
        # 配置文件格式
        file-extension: yml
        # 共享配置
        shared-configs:
          - application
    sentinel:
      # 取消控制台懒加载
      eager: true
      transport:
        # 控制台地址
        dashboard: 127.0.0.1:8718
      # nacos配置持久化
      datasource:
        ds1:
          nacos:
            server-addr: 127.0.0.1:8848
            dataId: sentinel-ruoyi-gateway
            groupId: DEFAULT_GROUP
            data-type: json
            rule-type: gw-flow
EOF

cat > Dockerfile << EOF
FROM ${Image}
WORKDIR /usr/local/src/
ADD ./ruoyi-gateway/target/ruoyi-gateway.jar /usr/local/src/ruoyi-gateway.jar
ADD app.yml .
ADD entrypoint.sh .
ENTRYPOINT ["sh","./entrypoint.sh"]
EOF

docker build -t ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID} .
'''
                }
            }
        }

        stage('推送镜像') {
            steps {
              container('docker') {
                withCredentials([usernamePassword(credentialsId: "${harbor_auth}", passwordVariable: 'password', usernameVariable: 'username')]) {
                sh """
                docker login -u ${username} -p '${password}' harbor.huanghuanhui.cloud
                docker push ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}
                """
                   }
                }
            }
        }

        stage('argo-rollouts + istio（金丝雀发布）（渐进式交付）') {
            steps {
              container('kubectl') {
              configFileProvider([configFile(fileId: "${kubectl_auth}", variable: 'kubeconfig')]) {
                sh """
                mkdir -p ~/.kube && cp ${kubeconfig} ~/.kube/config
                 /app/kubectl-argo-rollouts-linux-amd64 set image ${AppName} "*=${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}" -n ruoyi
                """
                   }
                }
            }
        }
    }
    post {
        success {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建成功：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=8CE600 >成功</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }
        
        failure {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建失败：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=#EE0000 >失败</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }

    }

}
```

### 2、ruoyi-auth-pipeline

```shell
# 参数化构建
AppName
服务名称
ruoyi-auth

GitRepo
代码仓库
http://gitlab.huanghuanhui.cloud/root/RuoYi-Cloud.git

GitBranch
master
代码分支

HarborUrl
镜像仓库地址
harbor.huanghuanhui.cloud

Image
基础镜像
ccr.ccs.tencentyun.com/huanghuanhui/openjdk:8-jre

JAVA_OPTS
jar 运行时的参数配置
-Xms1024M -Xmx1024M -Xmn256M -Dspring.config.location=app.yml -Dserver.tomcat.max-threads=800
```

```shell
#!/usr/bin/env groovy

def git_auth = "77066368-e8a8-4edb-afaf-53aaf90c31a9"
def harbor_auth = "9c10572f-c324-422f-b0c0-1b80d2ddb857"
def kubectl_auth = "c26898c2-92c3-4c19-8490-9cf8ff7918ef"

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  name: jenkins-slave
  namespace: jenkins-prod
spec:
  tolerations:
  - key: "no-pod"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: docker
    #image: docker:24.0.6
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6
    imagePullPolicy: IfNotPresent
    readinessProbe:
      exec:
        command: [sh, -c, "ls -S /var/run/docker.sock"]
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: docker-daemon
    #image: docker:24.0.6-dind
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6-dind
    imagePullPolicy: IfNotPresent
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: maven
    #image: maven:3.8.1-jdk-8
    image: ccr.ccs.tencentyun.com/huanghuanhui/maven:3.8.1-jdk-8
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2/repository
  - name: kubectl
    image: kostiscodefresh/kubectl-argo-rollouts:v1.6.0
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
  volumes:
  - name: docker-socket
    emptyDir: {}
  - name: maven-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-maven-cache
  - name: node-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-node-cache
'''
        }
    }

environment {
AppName = "${AppName}"
GitRepo = "${GitRepo}"
GitBranch = "${GitBranch}"
HarborUrl = "${HarborUrl}"
Image = "${Image}"
JAVA_OPTS = "${JAVA_OPTS}"
}

    stages {
        stage('拉取代码') {
			steps {
			git branch: "${GitBranch}", credentialsId: "${git_auth}", url: "${GitRepo}"
			}
		}

        stage('代码编译') {
            steps {
              container('maven') {
                sh """
                  mvn -U clean install -Dmaven.test.skip=true
                """
                }
            }
        }

        stage('打包镜像') {
            steps {
              script {env.GIT_COMMIT_MSG = sh (script: 'git rev-parse --short HEAD', returnStdout: true).trim()}
              container('docker') {
sh '''cat > entrypoint.sh << EOF
#! /bash/bin -e
env
java $JAVA_OPTS -jar ./*.jar
EOF

cat > app.yml << EOF
# Tomcat
server:
  port: 9200

# Spring
spring:
  application:
    # 应用名称
    name: ruoyi-auth
  profiles:
    # 环境配置
    active: dev
  cloud:
    nacos:
      discovery:
        # 服务注册地址
        server-addr: nacos-headless.nacos.svc.cluster.local:8848
      config:
        # 配置中心地址
        server-addr: nacos-headless.nacos.svc.cluster.local:8848
        # 配置文件格式
        file-extension: yml
        # 共享配置
        shared-configs:
          - application
EOF

cat > Dockerfile << EOF
FROM ${Image}
WORKDIR /usr/local/src/
ADD ./ruoyi-auth/target/ruoyi-auth.jar /usr/local/src/ruoyi-auth.jar
ADD app.yml .
ADD entrypoint.sh .
ENTRYPOINT ["sh","./entrypoint.sh"]
EOF

docker build -t ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID} .
'''
                }
            }
        }

        stage('推送镜像') {
            steps {
              container('docker') {
                withCredentials([usernamePassword(credentialsId: "${harbor_auth}", passwordVariable: 'password', usernameVariable: 'username')]) {
                sh """
                docker login -u ${username} -p '${password}' harbor.huanghuanhui.cloud
                docker push ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}
                """
                   }
                }
            }
        }

        stage('argo-rollouts + istio（金丝雀发布）（渐进式交付）') {
            steps {
              container('kubectl') {
              configFileProvider([configFile(fileId: "${kubectl_auth}", variable: 'kubeconfig')]) {
                sh """
                mkdir -p ~/.kube && cp ${kubeconfig} ~/.kube/config
                 /app/kubectl-argo-rollouts-linux-amd64 set image ${AppName} "*=${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}" -n ruoyi
                """
                   }
                }
            }
        }
    }
    post {
        success {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建成功：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=8CE600 >成功</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }
        
        failure {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建失败：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=#EE0000 >失败</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }

    }

}
```

### 3、ruoyi-system-pipeline

```shell
# 参数化构建
AppName
服务名称
ruoyi-system

GitRepo
代码仓库
http://gitlab.huanghuanhui.cloud/root/RuoYi-Cloud.git

GitBranch
master
代码分支

HarborUrl
镜像仓库地址
harbor.huanghuanhui.cloud

Image
基础镜像
ccr.ccs.tencentyun.com/huanghuanhui/openjdk:8-jre

JAVA_OPTS
jar 运行时的参数配置
-Xms1024M -Xmx1024M -Xmn256M -Dspring.config.location=app.yml -Dserver.tomcat.max-threads=800
```

```shell
#!/usr/bin/env groovy

def git_auth = "77066368-e8a8-4edb-afaf-53aaf90c31a9"
def harbor_auth = "9c10572f-c324-422f-b0c0-1b80d2ddb857"
def kubectl_auth = "c26898c2-92c3-4c19-8490-9cf8ff7918ef"

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  name: jenkins-slave
  namespace: jenkins-prod
spec:
  tolerations:
  - key: "no-pod"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: docker
    #image: docker:24.0.6
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6
    imagePullPolicy: IfNotPresent
    readinessProbe:
      exec:
        command: [sh, -c, "ls -S /var/run/docker.sock"]
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: docker-daemon
    #image: docker:24.0.6-dind
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6-dind
    imagePullPolicy: IfNotPresent
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: maven
    #image: maven:3.8.1-jdk-8
    image: ccr.ccs.tencentyun.com/huanghuanhui/maven:3.8.1-jdk-8
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2/repository
  - name: kubectl
    image: kostiscodefresh/kubectl-argo-rollouts:v1.6.0
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
  volumes:
  - name: docker-socket
    emptyDir: {}
  - name: maven-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-maven-cache
  - name: node-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-node-cache
'''
        }
    }

environment {
AppName = "${AppName}"
GitRepo = "${GitRepo}"
GitBranch = "${GitBranch}"
HarborUrl = "${HarborUrl}"
Image = "${Image}"
JAVA_OPTS = "${JAVA_OPTS}"
}

    stages {
        stage('拉取代码') {
			steps {
			git branch: "${GitBranch}", credentialsId: "${git_auth}", url: "${GitRepo}"
			}
		}

        stage('代码编译') {
            steps {
              container('maven') {
                sh """
                  mvn -U clean install -Dmaven.test.skip=true
                """
                }
            }
        }

        stage('打包镜像') {
            steps {
              script {env.GIT_COMMIT_MSG = sh (script: 'git rev-parse --short HEAD', returnStdout: true).trim()}
              container('docker') {
sh '''cat > entrypoint.sh << EOF
#! /bash/bin -e
env
java $JAVA_OPTS -jar ./*.jar
EOF
cat > app.yml << EOF
# Tomcat
server:
  port: 9201

# Spring
spring:
  application:
    # 应用名称
    name: $AppName
  profiles:
    # 环境配置
    active: dev
  cloud:
    nacos:
      discovery:
        # 服务注册地址
        server-addr: nacos-headless.nacos.svc.cluster.local:8848
      config:
        # 配置中心地址
        server-addr: nacos-headless.nacos.svc.cluster.local:8848
        # 配置文件格式
        file-extension: yml
        # 共享配置
        shared-configs:
          - application
EOF

cat > Dockerfile << EOF
FROM ${Image}
WORKDIR /usr/local/src/
ADD ./ruoyi-modules/ruoyi-system/target/ruoyi-modules-system.jar /usr/local/src/ruoyi-modules-system.jar
ADD app.yml .
ADD entrypoint.sh .
ENTRYPOINT ["sh","./entrypoint.sh"]
EOF

docker build -t ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID} .
'''
                }
            }
        }

        stage('推送镜像') {
            steps {
              container('docker') {
                withCredentials([usernamePassword(credentialsId: "${harbor_auth}", passwordVariable: 'password', usernameVariable: 'username')]) {
                sh """
                docker login -u ${username} -p '${password}' harbor.huanghuanhui.cloud
                docker push ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}
                """
                   }
                }
            }
        }

        stage('argo-rollouts + istio（金丝雀发布）（渐进式交付）') {
            steps {
              container('kubectl') {
              configFileProvider([configFile(fileId: "${kubectl_auth}", variable: 'kubeconfig')]) {
                sh """
                mkdir -p ~/.kube && cp ${kubeconfig} ~/.kube/config
                 /app/kubectl-argo-rollouts-linux-amd64 set image ${AppName} "*=${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}" -n ruoyi
                """
                   }
                }
            }
        }
    }
    post {
        success {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建成功：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=8CE600 >成功</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }
        
        failure {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建失败：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=#EE0000 >失败</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }

    }

}
```

### 4、ruoyi-vue-pipeline

```shell
# 参数化构建
AppName
服务名称
ruoyi-vue

GitRepo
代码仓库
http://gitlab.huanghuanhui.cloud/root/RuoYi-Cloud.git

GitBranch
master
代码分支

HarborUrl
镜像仓库地址
harbor.huanghuanhui.cloud

Image
基础镜像
ccr.ccs.tencentyun.com/huanghuanhui/nginx:1.25.3-alpine
```

```shell
#!/usr/bin/env groovy

def git_auth = "77066368-e8a8-4edb-afaf-53aaf90c31a9"
def harbor_auth = "9c10572f-c324-422f-b0c0-1b80d2ddb857"
def kubectl_auth = "c26898c2-92c3-4c19-8490-9cf8ff7918ef"

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  name: jenkins-slave
  namespace: jenkins-prod
spec:
  tolerations:
  - key: "no-pod"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: docker
    #image: docker:24.0.6
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6
    imagePullPolicy: IfNotPresent
    readinessProbe:
      exec:
        command: [sh, -c, "ls -S /var/run/docker.sock"]
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: docker-daemon
    #image: docker:24.0.6-dind
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:24.0.6-dind
    imagePullPolicy: IfNotPresent
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: node
    #image: node:16.17.0-alpine
    image: ccr.ccs.tencentyun.com/huanghuanhui/node:16.17.0-alpine
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: node-cache
      mountPath: /root/.npm
  - name: kubectl
    image: kostiscodefresh/kubectl-argo-rollouts:v1.6.0
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
  volumes:
  - name: docker-socket
    emptyDir: {}
  - name: maven-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-maven-cache
  - name: node-cache
    persistentVolumeClaim:
      claimName: jenkins-prod-slave-node-cache
'''
        }
    }

environment {
AppName = "${AppName}"
GitRepo = "${GitRepo}"
GitBranch = "${GitBranch}"
HarborUrl = "${HarborUrl}"
Image = "${Image}"
JAVA_OPTS = "${JAVA_OPTS}"
}

    stages {
        stage('拉取代码') {
			steps {
			git branch: "${GitBranch}", credentialsId: "${git_auth}", url: "${GitRepo}"
			}
		}

        stage('代码编译') {
            steps {
              container('node') {
                sh """
                  cd ruoyi-ui && sed -i \'s/localhost/ruoyi-gateway-svc/g\' vue.config.js && npm install --registry=https://registry.npm.taobao.org && npm run build:prod
                """
                }
            }
        }

        stage('打包镜像') {
            steps {
              script {env.GIT_COMMIT_MSG = sh (script: 'git rev-parse --short HEAD', returnStdout: true).trim()}
              container('docker') {
sh '''cat > nginx.conf << 'EOF'
worker_processes  auto;

events {
    worker_connections  10240;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen       80;
        server_name  localhost;

        location / {
            root   /usr/share/nginx/html;
            try_files $uri $uri/ /index.html;
            index  index.html index.htm;
        }

        location /prod-api/{
            proxy_pass http://ruoyi-gateway-svc:8080/;
            proxy_set_header Host $http_host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header REMOTE-HOST $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_http_version 1.1;
        }

        # 避免actuator暴露
        if ($request_uri ~ "/actuator") {
            return 403;
        }

        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   html;
        }
    }
}
EOF

cat > dockerfile << 'EOF'
FROM ccr.ccs.tencentyun.com/huanghuanhui/nginx:1.25.3-alpine

WORKDIR /usr/share/nginx/html

COPY nginx.conf /etc/nginx/nginx.conf

COPY ./ruoyi-ui/dist /usr/share/nginx/html
EOF

docker build -t ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID} .
'''
                }
            }
        }

        stage('推送镜像') {
            steps {
              container('docker') {
                withCredentials([usernamePassword(credentialsId: "${harbor_auth}", passwordVariable: 'password', usernameVariable: 'username')]) {
                sh """
                docker login -u ${username} -p '${password}' harbor.huanghuanhui.cloud
                docker push ${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}
                """
                   }
                }
            }
        }

        stage('argo-rollouts + istio（金丝雀发布）（渐进式交付）') {
            steps {
              container('kubectl') {
              configFileProvider([configFile(fileId: "${kubectl_auth}", variable: 'kubeconfig')]) {
                sh """
                mkdir -p ~/.kube && cp ${kubeconfig} ~/.kube/config
                 /app/kubectl-argo-rollouts-linux-amd64 set image ${AppName} "*=${HarborUrl}/ruoyi-cloud/${AppName}:${GitBranch}-${GIT_COMMIT_MSG}-${BUILD_ID}" -n ruoyi
                """
                   }
                }
            }
        }
    }
    post {
        success {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建成功：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=8CE600 >成功</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }
        
        failure {
            dingtalk (
                robot: "Jenkins-Dingtalk",
                type:'ACTION_CARD',
                atAll: false,
                title: "构建失败：${env.JOB_NAME}",
                //messageUrl: 'xxxx',
                text: [
                    "### [${env.JOB_NAME}](${env.JOB_URL}) ",
                    '---',
                    "- 任务：[${currentBuild.displayName}](${env.BUILD_URL})",
                    '- 状态：<font color=#EE0000 >失败</font>',
                    "- 持续时间：${currentBuild.durationString}".split("and counting")[0],
                    "- 执行人：${currentBuild.buildCauses.shortDescription}",
                    "- 环境：开发环境",
                    "- 构建日志地址：${BUILD_URL}console",
                ]
           )
        }

    }

}
```

