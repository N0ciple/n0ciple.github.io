---
layout: post
title: Ethereum mining with docker
date: 2021-10-21 20:56 +0200
---
# About Ethereum and Ethereum mining

**Ethereum** is the second most popular cryptocurency by volume on the internet. One nice things about it that it has been concieved to be **ASICs-proof**. You can _in theory_ only mine ETH on a GPU or CPU. It is to say that you could help secure the blockchain and more importantly **earn a bit of ETH** from you computer, no need for an expensive and **noisy ASIC miner** !

If you want to mine cryptocurency easily you can use premades binary (such as [T-Rex miner](https://trex-miner.com/)) or services (such as [NiceHash](https://www.nicehash.com/)). However bear in mind that most of these binaries or services take **a small fee**, generally arround **1%** of you hard-earned ETH. If you would rather keep these 1% for you or use **open source software**, this is possible thanks to [ethminer](https://github.com/ethereum-mining/ethminer)!

Ethminer is an opensource ethereum miner written in C++ and compatible with both AMD (through OpenCL) and Nvidia (through CUDA) GPUs. The latest release of ethminer is from **july 2019**, and are build against CUDA 9 at most. With **CUDA 9** you **will not** be able to run ethminer on the **most recents Nvida cards** (RTX 3000 series for example requires at least CUDA 11.1). Therefore you will need to **build ethminer yourself** if you want to use recent GPUs. This is far from impossible but a bit tidious since ethminer uses Hunter to fetch some dependancies. Hunter uses Bintray, which have been [sunseted](https://jfrog.com/blog/into-the-sunset-bintray-jcenter-gocenter-and-chartcenter/) on the 1rst of May 2021.

To keep this simple the easiest way is to use ethminer is to use a **docker container** that does all the hard work of building and runing ethminer for you. If you just want to use the docker image directly, jump to the [section](#running) about actually runnig ethminer. If you want some details about how to make the **Dockerfile** follow through the next section !

# Creating the Dockerfile

In order to build our docker container we are going to write a `Dockerfile`  that will contain all the instruction to create the docker image. The original building instructions specific to ethminer can be found on the [`docs/BUILD.md`](https://github.com/ethereum-mining/ethminer/blob/master/docs/BUILD.md) file of the ethermine repo.

In our Dockerfile, we first start by writing the following line that allows us to use a premade image from Nvidia containing the drivers as a base image, on top of which we will install the drivers. As you can see here our docker image will have the driver version `460.73.01`.

```Dockerfile
FROM nvidia/driver:460.73.01-ubuntu20.04
```
Then we update the sources and install the necessary dependencies to build ethminer.\
The environment variable `DEBIAN_FRONTEND` is here to prevent `apt-get` from asking us questions since the installation process is supposed to be unatended. That is also why we add `-y` : to accept without further input from `apt-get`
```Dockerfile
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install kmod git cmake perl gcc g++ wget --no-install-recommends -yq
```

We fetch the cuda install script, run it and finaly delete it in the same `RUN` statement to prevent the addition of a lot of useless layer in the creation of the docker image. Here we download CUDA version `11.4.2`
```Dockerfile
RUN wget --no-check-certificate https://developer.download.nvidia.com/compute/cuda/11.4.2/local_installers/cuda_11.4.2_470.57.02_linux.run && \
    sh cuda_11.4.2_470.57.02_linux.run --silent --toolkit --no-man-page --no-opengl-libs && \
    rm cuda_11.4.2_470.57.02_linux.run 
```
We change our working directory to `/`.
```Dockerfile
WORKDIR "/"
```

This big one-liner is responsible for cloning, configuring, building ethminer and finaly removing the useless files. This command is quite a big chunk so I will explained it in details. I used a big oneline once again to limit the number of layers generated.
```Dockerfile
RUN git clone https://github.com/ethereum-mining/ethminer.git -o ethminer && \
    cd /ethminer && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    # Hack because bintray does not exists anymore
    # see https://unix.stackexchange.com/questions/652841/boost-continually-fails-to-download-while-using-cmake-for-ethminer
    sed -i '/hunter_config(Boost VERSION 1.66.0)/c\hunter_config(\n     Boost\n     VERSION 1.66.0_new_url\n     SHA1 f0b20d2d9f64041e8e7450600de0267244649766\n     URL https://boostorg.jfrog.io/artifactory/main/release/1.66.0/source/boost_1_66_0.tar.gz\ )' /ethminer/cmake/Hunter/config.cmake && \
    cmake .. -DETHASHCL=OFF -DAPICORE=ON -DETHASHCUDA=ON -DBINKERN=OFF && \
    cmake --build . && \
    make install && \
    cd / && rm -rf ethminer
```
In this command we first clone the repo on a folder called `ethminer`. We then basically follow the building instruction from the ethminer repo, but before the configuring, we use a big `sed` command to edit the **Hunter configuration**. This is necessary since without this modification, Hunter is going to try to fetch Boost on Bintray and **fail**. Downloading manualy Boost is not going to work either, since the **hash does not correspond** to the one expected by Hunter, hence this modification with `sed`. More details [here](https://unix.stackexchange.com/questions/652841/boost-continually-fails-to-download-while-using-cmake-for-ethminer).\
Once the modification of the Hunter `config.cmake` file is done, we generate the build configuration with 4 flags. `-DETHASHCL=OFF` **disable OpenCL**, since it is for AMD GPUs. However, ethminer is able to mine on both AMD and Nvidia GPUs at the same time. So if you want to mine Ethereum on such a hardware configuration, enable OpenCL with `-DETHASHCL=ON`. `-DAPICORE=ON` Enables the API (more details on that later). `-DETHASHCUDA=ON` makes sure **CUDA support is enabled**. And finally `-DBINKERN=OFF` prevent the installation of AMD binary kernels (once again, enable if you want to use AMD GPUs).\
Once this is done we actually build ethminer, then install it (so that it is in our `$PATH`). and finally **delete the repo directory** as we do not need any of these files anymore.\

Now we **expose port `3333`** (or any other port that you want to use) to access the API. The API is a **simple web page** with a few statistics such as the list of the GPUs, their temperature, fan speed and hash rate. This is helpful since we can **easily access all these informations** without having to look at the **docker logs**.
```Dockerfile
EXPOSE 3333
```
Example of the ethminer API :
<img alt="Example of ethminer API" class="img-fluid rounded " src="{{ site.baseurl }}/assets/img/blog/ethminer_api_example.png" data-zoomable>

Finally we have to **overrive** our base image entrypoint by adding a **new one** !
```Dockerfile
ENTRYPOINT ["bash"]
```

The final Dockerfile is named `Dockerfile` (no extension) and contains the following :
```Dockerfile
FROM nvidia/driver:460.73.01-ubuntu20.04

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install kmod git cmake perl gcc g++ wget --no-install-recommends -yq

RUN wget --no-check-certificate https://developer.download.nvidia.com/compute/cuda/11.4.2/local_installers/cuda_11.4.2_470.57.02_linux.run && \
    sh cuda_11.4.2_470.57.02_linux.run --silent --toolkit --no-man-page --no-opengl-libs && \
    rm cuda_11.4.2_470.57.02_linux.run 

WORKDIR "/"

RUN git clone https://github.com/ethereum-mining/ethminer.git -o ethminer && \
    cd /ethminer && \
    git submodule update --init --recursive && \
    mkdir build && cd build && \
    sed -i '/hunter_config(Boost VERSION 1.66.0)/c\hunter_config(\n     Boost\n     VERSION 1.66.0_new_url\n     SHA1 f0b20d2d9f64041e8e7450600de0267244649766\n     URL https://boostorg.jfrog.io/artifactory/main/release/1.66.0/source/boost_1_66_0.tar.gz\ )' /ethminer/cmake/Hunter/config.cmake && \
    cmake .. -DETHASHCL=OFF -DAPICORE=ON -DETHASHCUDA=ON -DBINKERN=OFF && \
    cmake --build . && \
    make install && \
    cd / && rm -rf ethminer

EXPOSE 3333

ENTRYPOINT [ "bash" ]
```

# Building our Docker image

One we have our Dockerfile this is a rather **easy step**. Assuming that you are in a directory containing only you dockerfile, run
```bash
docker build -t ethminer .
```
⚠️ _Do not foget the dot at the end of the command (it means "the current directory") !_

You can change `ethermine` by what you want. It is the **name of your docker image**. You can confirm your docker image is on you system by running `docker image ls`. This should give something like this :
```bash
REPOSITORY               TAG                     IMAGE ID       CREATED        SIZE
ethminer                 latest                  bcf676a57879   6 hours ago    7.15GB
```

<!--RUN echo "# Setup to use less energy\n \
# Set persistent mode\n \
nvidia-smi -pm 1\n \
# set power limit to 60 for GPU 1 : GTX 1060\n \
nvidia-smi -i 1 -pl 60\n \
# set power limit to 120 for GPU 0 : RTX 3070\n \
nvidia-smi -i 0 -pl 120\n \
# Start mining\n \
ethminer --HWMON 2 -P stratum1+ssl://0x29c3765d6026337a0Bc9b95Bf4Dd3308F4217e20@eu1.ethermine.org:5555 --api-port 3333\n \
" > mining.sh
ENTRYPOINT [ "bash", "mining.sh" ]
# ENTRYPOINT [ "bash" ] -->

# Running ethminer on docker <a name="running"></a>

before running ethminer you need to **install `nvidia-docker`**. This is a **wrapper** that allows docker to **access your GPUs** ! To install it, run :
```bash
sudo apt install nvidia-docker
```
Once this is done, you can run the container with :
```bash
docker run -p 3333 -d --name my_ethminer ethminer <your ethminer command>
```
⚠️ _Replace_ `<your ethminer command>` _by the command you use to start ethminer with the mining options._

The `-p 3333` option allows to acces the ethminer API on port 3333 of the machine you are currenlty running it on. `--name my_ethminer` gives a friendly name to you container. The `-d` makes the docker container running in detached mode. If you want to see the logs run :

```bash
docker logs -f my_ethminer
```