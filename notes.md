## BuildTest.test_build_invalid_platform

Building a container with an invalid platform should fail. Podman happily builds it.
Podman totally ignores the parameter (i.e. doesn't forward it to Buildah).
When patching it through to Buildah's `Architecture` build option it's ignored by Buildah.

Docker's response:
`400 {"message":"\"foobar\": unknown operating system or architecture: invalid argument"}`



## ContainerTest.test_kill

Killing a container sometimes changes to state 'stopped' and sometimes to 'exited'.
It should be 'exited'.



## ContainerTest.test_diff

Running `touch /test` in a container also changes /etc (see container diff)



## CreateContainerTest.test_create_container_with_volumes_from

Some test started getting flaky around beginning of June 2021.

exemplary error:
`500 Server Error for http+docker://localhost/v1.40/containers/23526eab673a42f9a90c5caff84c215da46f77ab6ff1153190fc928d0d63aba9/start: Internal Server Error ("error configuring network namespace for container 23526eab673a42f9a90c5caff84c215da46f77ab6ff1153190fc928d0d63aba9: failed to Statfs "/run/user/1000/netns/cni-a78e37ad-923c-5099-e2ba-18ff619d9a6e": no such file or directory")`

other tests exhibit similar behaviour:
- CreateContainerTest.test_valid_no_log_driver_specified
- StartContainerTest.test_run_shlex_command
- AttachContainerTest.test_attach_no_stream
- PruneTest.test_prune_containers
- ContainerCollectionTest.test_run_with_named_volume
- ContainerTest.test_commit



## TestNetworks.test_create_with_ipv4_address

exemplary error:
`500 Server Error for http+docker://localhost/v1.40/containers/6abe322fc4312da127ba97455a8e533153681aed269835283ef2a3a41ec23a30/start: Internal Server Error ("error configuring network namespace for container 6abe322fc4312da127ba97455a8e533153681aed269835283ef2a3a41ec23a30: failed to set bridge addr: "cni-podman1" already has an IP address different from 132.124.0.1/16"*`

other tests exhibit similar behaviour:
- TestNetworks.test_connect_with_ipv4_address
- TestNetworks.test_create_with_ipv6_address



## BuildTest.test_build_with_cache_from

2022-01-07 Podman 4.0.0-dev:
Podman always uses cached layers and ignores the `cachefrom` parameter.
