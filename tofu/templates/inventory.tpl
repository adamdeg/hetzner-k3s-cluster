[master]
%{ for ip in master_nodes ~}
${ip} ansible_user=root
%{ endfor ~}

[worker]
%{ for ip in worker_nodes ~}
${ip} ansible_user=root
%{ endfor ~}

[k3s_cluster:children]
master
worker