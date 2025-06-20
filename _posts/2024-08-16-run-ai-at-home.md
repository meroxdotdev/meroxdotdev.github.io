---
title: How to Set Up Your Own AI at Home
date: 2024-08-16 10:00:00 +0200
categories: [infrastructure]
tags: [ai, self-hosting, server, ollama, stable-diffusion]
description: Learn how to set up AI at home with Ollama, OpenWebUI and Stable Diffusion in this guide.
image:
  path: /assets/img/posts/ai-home-setup.webp
  alt: AI Home Setup with Ollama and Stable Diffusion
---

Recently, I started exploring the field of AI to better understand what my home lab setup is capable of. This time, I used a Dell PowerEdge R720 server, equipped with 192 GB of RAM, dual 6-core CPUs (24 threads), and no GPU, to familiarize myself with various AI tools. Having done some investigation into this matter, three major tools attracted my attention—Stable Diffusion, OpenWebUI and Ollama. Each tool has unique features while together they make up a functional AI environment for me to play around with.

**Below are brief descriptions of the tools:**

- **Stable Diffusion**: A model that generates high-quality images from text prompts, ideal for exploring AI-generated art.
- **OpenWebUI**: An intuitive interface that makes it easier to manage and interact with AI models.
- **Ollama**: A versatile AI framework designed for seamless integration and reliable performance.

In this article, I will go over how I set these tools up on my server as well as their configurations. The difficulties that were there, the solutions I found and useful tips that may be helpful when working under similar conditions will also be shared. Even though still new in Artificial Intelligence systems at least my experience can be of great help to others who may want to start too.

## Setting Up Ollama: My First Step into AI

The first tool I tackled was **Ollama**. After doing some research, it seemed like a good starting point because of its straightforward setup and broad compatibility. Ollama is a flexible AI framework that can be installed on all major platforms—**Linux**, **MacOS**, and **Windows**—which made it accessible no matter what system you're running. Plus, it provides a solid foundation for further AI experiments, which is exactly what I needed for my home lab.

### Installing Ollama on Linux

I began by setting up Ollama on a virtual machine running **Ubuntu 22.04** in my **Proxmox** environment. I allocated **20 cores** and **64GB of RAM** to this VM to ensure smooth performance during testing.

To install Ollama, I used the following command:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Downloading the Llama3 Model

Once the installation was complete, the next step was to download a model to work with. I chose the Llama3 model, which is known for its performance in various AI tasks. To download it, I ran the command:

```bash
ollama pull llama3
```

### Running the Llama3 Model

```bash
ollama run llama3
```

### Example: Llama3 CLI Interaction

> **Question**: How does the concept of time dilation in *Interstellar* relate to Einstein's theory of relativity?
{: .prompt-info }

> **Answer**: The concept of time dilation in Interstellar is directly related to Albert Einstein's theory of special relativity, specifically the concept of time dilation. Here's how: In the movie, a wormhole allows Cooper's spaceship to travel at incredibly high speeds, approaching relativistic velocities. As they approach the speed of light (0.99c), time appears to slow down for them relative to Earth. This is precisely what Einstein predicted in his theory...
{: .prompt-tip }

## Setting Up Stable Diffusion

**Stable Diffusion** is a powerful model for generating high-quality images from text prompts. Setting it up on my Ubuntu 22.04 VM was quite straightforward thanks to the clear installation guide provided in the [official GitHub repository](https://github.com/AUTOMATIC1111/stable-diffusion-webui).

### Installation Steps

Here's a summary of the steps I followed to install Stable Diffusion:

#### 1. Install the Dependencies

Depending on your Linux distribution, use one of the following commands to install the necessary dependencies:

**Debian-based (e.g., Ubuntu):**
```bash
sudo apt install wget git python3 python3-venv libgl1 libglib2.0-0
```

**Red Hat-based:**
```bash
sudo dnf install wget git python3 gperftools-libs libglvnd-glx
```

**openSUSE-based:**
```bash
sudo zypper install wget git python3 libtcmalloc4 libglvnd
```

#### 2. Download the Web UI Script

Navigate to the directory where you want to install Stable Diffusion and execute the following command:

```bash
wget -q https://raw.githubusercontent.com/AUTOMATIC1111/stable-diffusion-webui/master/webui.sh
```

#### 3. Run the WebUI Script

```bash
./webui.sh
```

#### 4. Configure the webui-user.sh File

Since my server does not have a GPU, I needed to adapt the `webui-user.sh` file to optimize performance for CPU usage. Specifically, I added the following line to configure the environment for CPU-only operation:

```bash
export COMMANDLINE_ARGS="--lowvram --precision full --no-half --skip-torch-cuda-test"
```

**Command arguments explained:**
- `--lowvram`: Reduces memory usage to accommodate systems with limited GPU memory
- `--precision full`: Ensures full precision calculations, useful for CPU processing
- `--no-half`: Disables half-precision calculations to avoid potential issues on CPUs
- `--skip-torch-cuda-test`: Skips tests related to CUDA, which is irrelevant on systems without GPUs

#### 5. Start the Web UI

By default, running the `webui.sh` command will start the server and bind it to localhost (127.0.0.1). To allow access from other interfaces (useful for integration with OpenWebUI), use the `--listen` parameter:

```bash
./webui.sh --listen
```

This command makes the server accessible on all network interfaces at port 7860 (0.0.0.0:7860).

![Stable Diffusion Web Interface](/assets/img/posts/stablediffusion.png){: width="700" height="400" }
_Stable Diffusion Web Interface_

## Setting Up OpenWebUI

With Ollama and Stable Diffusion installed and configured, the next step is to centralize these tools into a single, user-friendly interface. **OpenWebUI** provides a cohesive platform to interact with your AI models, similar to ChatGPT.

### Installation Steps

Setting up OpenWebUI is probably the easiest and quickest part of this tutorial, thanks to its well-organized and straightforward documentation. You can deploy OpenWebUI using Docker, which simplifies the installation process.

#### Installation with Default Configuration

If Ollama is running on the same server as OpenWebUI, use the following Docker command:

```bash
docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

If Ollama is hosted on a different server, you need to specify the URL of the Ollama server:

```bash
docker run -d -p 3000:8080 -e OLLAMA_BASE_URL=https://example.com \
  -v open-webui:/app/backend/data --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:main
```

For running OpenWebUI with Nvidia GPU support, use this command:

```bash
docker run -d -p 3000:8080 --gpus all --add-host=host.docker.internal:host-gateway \
  -v open-webui:/app/backend/data --name open-webui --restart always \
  ghcr.io/open-webui/open-webui:cuda
```

### Integrating Ollama and Stable Diffusion

Once OpenWebUI is up and running, the next step is to integrate it with Ollama and Stable Diffusion via API connections.

### Connecting Ollama

#### OpenWebUI Admin Settings

1. Open your browser and navigate to: `http://ip_server_openwebui:3000/admin/settings/`
2. Go to **Models** → **Manage Ollama Models**
3. Enter the **URL** of your Ollama server

![OpenWebUI Admin Settings](/assets/img/posts/openwebuiaset.png){: width="700" height="400" }
_OpenWebUI Admin Settings - If you're running Ollama and OpenWebUI on the same server, this step might be auto-filled_

### Connecting Stable Diffusion

1. Go to **Images** and find the **AUTOMATIC1111 Base URL** field
2. Enter the **URL** of your Stable Diffusion server
3. Press the **refresh check button** next to the URL to verify the connection with the Stable Diffusion server
4. If everything is working correctly, click **Save**
5. You can now adjust the parameters under **Set Default Model** according to your needs

![Stable Diffusion Integration](/assets/img/posts/stablediffusionaset.png){: width="700" height="400" }
_Stable Diffusion Integration Settings_

**Voilà!**

![OpenWebUI Interface](/assets/img/posts/meroxai.png){: width="700" height="400" }
_Unified AI Interface with OpenWebUI_

With OpenWebUI, Ollama, and Stable Diffusion all integrated, you now have a unified interface to interact with your AI models, making it easier to manage and utilize these powerful tools in your home lab.

## Conclusion

As I continue to explore and build my AI environment, I plan to enhance my setup with a dedicated GPU in the near future. I'm considering an NVIDIA TESLA P40, which should significantly boost performance and allow for more efficient processing. Once I have this upgrade in place, I'll provide updated information and tips on configuring AI tools with GPU support.

Currently, with my setup of dual Intel Xeon E5-2620 v2 CPUs at 2.10GHz, the performance is functional but not particularly fast. The experience has been quite interesting, offering valuable insights into AI integration and usage. Here are some performance metrics from my current setup with Ollama and Stable Diffusion:

| Metric | Value |
|:-------|:------|
| Response Token/s | 0.46 |
| Prompt Token/s | 1.99 |
| Total Duration | 1072376.46 ms (~17 min 52 sec) |
| Load Duration | 61347.1 ms |
| Prompt Eval Count | 33 |
| Prompt Eval Duration | 16571.72 ms |
| Eval Count | 457 |
| Eval Duration | 994411.07 ms |

These numbers illustrate the impact of running AI models on a CPU-only configuration. Despite the slower performance, the journey has been rewarding and informative.

Thank you for following along with my AI setup journey. I hope these insights and steps will be useful for anyone starting with AI tools in a similar environment. If you have any questions or need further assistance, feel free to reach out!

For those interested in GPU setups, here are some useful resources to help with GPU configuration:

## Credits

- [TechnoTim](https://www.youtube.com/watch?v=GrLpdfhTwLg&t=467s) - Comprehensive AI Setup Tutorial
- [Sean Zheng](https://medium.com/@blackhorseya/running-llama-3-model-with-nvidia-gpu-using-ollama-docker-on-rhel-9-0504aeb1c924) - Running Llama 3 Model with NVIDIA GPU