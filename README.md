# terraform-k8s

Antes de rodar o init ou plan, fazer as seguintes alterações:

    0. criar o arquivo terraform.tfvars
        cidr_block   = ""
        project_name = ""
        cluster_name   = ""
        aws_partition  = ""
        aws_account_id = ""

    1. editar arquivo provider.tf
        a. indicar a região correta
        b. indicar o state correto do s3

    2. editar arquivo modules.tf
        a. indicar os mapusers correto no resource edit_aws_auth_configmap

    3. login default grafana
        admin
        prom-operator