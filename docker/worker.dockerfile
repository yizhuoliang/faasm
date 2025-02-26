ARG FAASM_VERSION
ARG FAASM_SGX_PARENT_SUFFIX
FROM faasm.azurecr.io/base${FAASM_SGX_PARENT_SUFFIX}:${FAASM_VERSION}

# Build the worker binary
ARG FAASM_SGX_MODE
RUN cd /usr/local/code/faasm \
    && ./bin/create_venv.sh \
    && source venv/bin/activate \
    && inv dev.cmake \
        --build Release \
        --disable-spinlock \
        --sgx ${FAASM_SGX_MODE} \
    && inv dev.cc codegen_shared_obj \
    && inv dev.cc codegen_func \
    && inv dev.cc pool_runner

WORKDIR /build/faasm

# Install worker-specific deps
RUN apt update && apt install -y dnsutils \
    && pip3 install hoststats==0.1.0

# Set up entrypoint (for cgroups, namespaces etc.)
COPY bin/entrypoint_codegen.sh /entrypoint_codegen.sh
COPY bin/entrypoint_worker.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create user with dummy uid required by Python
RUN groupadd -g 1000 faasm
RUN useradd -u 1000 -g 1000 faasm

# Crazy command to parse the Taskset & NUMA configs from env
# TODO: should wrap this to some external script for better readability
ENTRYPOINT ["/entrypoint.sh"]
CMD ["bash", "-c", "\
  # Get a unique index from the identifier service\n\
  index=$(curl -s http://identifier:1081); \
  echo \"Received worker index: $index\"; \
  IFS=';' read -r -a taskset_list <<< \"$WORKER_TASKSET_LIST\"; \
  IFS=';' read -r -a numa_list <<< \"$WORKER_NUMA_NODE_LIST\"; \
  selected_taskset=${taskset_list[$((index-1))]}; \
  selected_numa=${numa_list[$((index-1))]}; \
  cmd='/build/faasm/bin/pool_runner'; \
  if [ -n \"$selected_taskset\" ]; then \
      cmd=\"taskset -c $selected_taskset $cmd\"; \
  fi; \
  if [ -n \"$selected_numa\" ]; then \
      cmd=\"numactl --cpunodebind=$selected_numa --membind=$selected_numa $cmd\"; \
  fi; \
  echo \"Final command to be executed: $cmd\"; \
  exec $cmd"]
