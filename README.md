# Monorepo container build action

## Why use this?

This is a quick custom action to for a private project.

The main problem it solves is where you have a monorepo of containers for a microservice based 
system (or similar) and due to shared dependencies, require pre-steps in the build process such
as copying files so that they become available in the docker build context.

This allows you to stipulate a build command to build your container, and the rest of the action
will pick up that image and push it based on your supplied configuration.

## Example configuration

In my case, I'm wanting to only build containers when they change which in some cases can be
rare, so creating a different action for each container makes sense and then filtering them
using the `on.push.paths` configuration like so.

```yaml
name: Build and push CONTAINER_NAME
on: 
  push:
    branches:
      - production
      - development
    paths: 
      # Only run this action when there are changes in the given container
      - 'path/to/CONTAINER_DIRECTORY/**'
jobs:
  buildAndPush:
    runs-on: ubuntu-latest 
    steps:
      - uses: actions/checkout@master
      - name: Build and push CONTAINER_NAME
        uses: ianbelcher/monorepo-container-build-action@master
        with:
          container_name: CONTAINER_NAME
          command_to_run: '(cd path/to/build/script && build.sh)'
          docker_registry: ${{ secrets.DOCKER_REGISTRY }}
          docker_registry_username: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
          docker_registry_password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
```

If you wish to just build all container without the `on.push.paths` filter on all pushes, then
you can combine into a single action like so.

```yaml
name: Build and push containers
on: 
  push:
    branches:
      - production
      - development
jobs:
  buildAndPush:
    runs-on: ubuntu-latest 
    steps:
      - uses: actions/checkout@master
      - name: Build and push CONTAINER_NAME
        uses: ianbelcher/monorepo-container-build-action@master
        with:
          container_name: CONTAINER_NAME
          command_to_run: '(cd path/to/build/script && build.sh)'
          docker_registry: ${{ secrets.DOCKER_REGISTRY }}
          docker_registry_username: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
          docker_registry_password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
      - name: Build and push SECOND_CONTAINER_NAME
        uses: ianbelcher/monorepo-container-build-action@master
        with:
          container_name: SECOND_CONTAINER_NAME
          command_to_run: '(cd path/to/build/second-script && build.sh)'
          docker_registry: ${{ secrets.DOCKER_REGISTRY }}
          docker_registry_username: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
          docker_registry_password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
```

From here, using `Consensys/k8s-gh-action` allows you to update you Kubernetes state for each of the
built containers quite easily using the output variable `IMAGE_URL`. Notice the use of setting
the id of the step (`monorepoContainerBuildActionId*`) and then accessing that value in the follow
up step.

```yaml
name: Build and push containers
on: 
  push:
    branches:
      - production
      - development
jobs:
  buildAndPush:
    runs-on: ubuntu-latest 
    steps:
      - uses: actions/checkout@master
      # First container
      - name: Build and push CONTAINER_NAME
        uses: ianbelcher/monorepo-container-build-action@master
        id: monorepoContainerBuildActionId1
        with:
          container_name: CONTAINER_NAME
          command_to_run: '(cd path/to/build/script && build.sh)'
          docker_registry: ${{ secrets.DOCKER_REGISTRY }}
          docker_registry_username: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
          docker_registry_password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
      - name: Update Deployment
        uses: Consensys/k8s-gh-action@master
        env:
          KUBE_CONFIG_DATA: ${{ secrets.KUBE_CONFIG_DATA }}
        with:
          args: set image --record deployment/CONTAINER_DEPLOYMENT_NAME CONTAINER_POD_NAME=${{ steps.monorepoContainerBuildActionId1.outputs.IMAGE_URL }}
      - name: Verify rollout
        uses: Consensys/k8s-gh-action@master
        env:
          KUBE_CONFIG_DATA: ${{ secrets.KUBE_CONFIG_DATA }}
        with:
          args: rollout status deployment/CONTAINER_DEPLOYMENT_NAME
      # Second container
      - name: Build and push SECOND_CONTAINER_NAME
        uses: ianbelcher/monorepo-container-build-action@master
        id: monorepoContainerBuildActionId2
        with:
          container_name: SECOND_CONTAINER_NAME
          command_to_run: '(cd path/to/build/second-script && build.sh)'
          docker_registry: ${{ secrets.DOCKER_REGISTRY }}
          docker_registry_username: ${{ secrets.DOCKER_REGISTRY_USERNAME }}
          docker_registry_password: ${{ secrets.DOCKER_REGISTRY_PASSWORD }}
      - name: Update Deployment
        uses: Consensys/k8s-gh-action@master
        env:
          KUBE_CONFIG_DATA: ${{ secrets.KUBE_CONFIG_DATA }}
        with:
          args: set image --record deployment/SECOND_CONTAINER_DEPLOYMENT_NAME SECOND_CONTAINER_POD_NAME=${{ steps.monorepoContainerBuildActionId2.outputs.IMAGE_URL }}
      - name: Verify rollout
        uses: Consensys/k8s-gh-action@master
        env:
          KUBE_CONFIG_DATA: ${{ secrets.KUBE_CONFIG_DATA }}
        with:
          args: rollout status deployment/SECOND_CONTAINER_DEPLOYMENT_NAME
```