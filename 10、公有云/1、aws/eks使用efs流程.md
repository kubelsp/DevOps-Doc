eks使用efs流程

```shell
ec2-idn

AmazonEC2ContainerRegistryReadOnly
AmazonEKS_CNI_Policy
AmazonEKSWorkerNodePolicy
AmazonSSMManagedInstanceCore
```

```shell
eks-idn-nat

16.79.197.101
108.137.64.112

```

```shell
10.10.0.0/20
10.10.32.0/20
10.10.16.0/20
```

1、eks添加插件（最后）

2、访问（容器组身份关联）

```shell
1、创建推荐的角色：AmazonEKS_EFS_CSI_DriverRole
权限策略 (名字）AmazonEFSCSIDriverPolicy
```

```shell
1、IAM 角色- AmazonEKS_EFS_CSI_DriverRole 
2、目标 IAM 角色 - 可选，新增 （不填）
3、Kubernetes 命名空间 - kube-system
4、Kubernetes 服务账户 - efs-csi-controller-sa
```

ebs

```shell
AmazonEKS_EBS_CSI_DriverRole
AmazonEBSCSIDriverPolicy


ebs-csi-controller-sa
```

