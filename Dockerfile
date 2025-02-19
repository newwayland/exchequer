FROM docker.io/library/ruby:3.4

# Install necessary packages
# RUN apt-get update && apt-get install -y \
#     build-essential \
#     && rm -rf /var/lib/apt/lists/*

# Set a non-root user for security
RUN useradd -m simulator
WORKDIR /app
USER simulator

# Copy Gemfile and install dependencies
COPY --chown=simulator:simulator Gemfile ./
COPY --chown=simulator:simulator .bundle/config /usr/local/bundle/
RUN bundle install

# Copy the application code
COPY --chown=simulator:simulator . .


# Run the application
ENTRYPOINT ["/usr/local/bin/bundle", "exec"]
CMD ["ruby", "lib/main.rb"]
