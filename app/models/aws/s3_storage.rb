module Aws
  class S3Storage
    ENV_LIST = ['local', 'prod', 'preprod']

    def initialize
      setup
    end

    # If success, return URI which has the s3 bucket key
    # else return nil
    # raises exception if exception occurs
    def save(file_path, bucket_name, key=SecureRandom.uuid)
      bucket_name = env_bucket_name(bucket_name)
      uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}##{key}"
      begin
        object = get_object(bucket_name, key)
        if object.upload_file(file_path, :server_side_encryption => 'AES256')
          uri
        else
          nil
        end
      rescue Exception => e
        raise e
      end
    end

    def save_h41(file_path, bucket_name, key=SecureRandom.uuid)
      bucket_name = env_bucket_name(bucket_name, "h41")
      uri = "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}##{key}"
      begin
        object = get_object(bucket_name, key)
        object.upload_file(file_path, :server_side_encryption => 'AES256')
        if file_path.in?(`aws s3 ls s3://#{hbx_id}-enroll-aca-internal-artifact-transport-#{aws_env}/`)
          {object: object, uri: uri, full_file_name: file_path } 
        else
          puts "File not uploaded"
        end
      rescue Exception => e
        raise e
      end
    end

    # If success, return URI which has the s3 bucket key
    # else return nil
    def self.save(file_path, bucket_name, key=SecureRandom.uuid, h41 = nil)
      h41.present? ? Aws::S3Storage.new.save_h41(file_path, bucket_name, key) : Aws::S3Storage.new.save(file_path, bucket_name, key)
    end

    # Here's an option to publish to SFTP.
    def self.publish_to_sftp(policy, filename, transport_process, uri)
      policy_id = policy.id
      eg_id = policy.eg_id
      conn = AmqpConnectionProvider.start_connection
      eb = Amqp::EventBroadcaster.new(conn)
      aws_key = uri.split("#").last
      filename =  File.basename(filename, ".zip")  
      props = {:headers => {:artifact_key => aws_key, :file_name => filename, :transport_process => transport_process, :policy_id => policy_id, :eg_id => eg_id, :submitted_timestamp => Time.now.to_s}, :routing_key => "info.events.transport_artifact.transport_requested"}
      eb.broadcast(props, "payload")
      conn.close
    end

    # The uri has information about the bucket name and key
    # e.g. "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}##{key}"
    # The returned object can be streamed by controller
    # e.g. send_data Aws::S3Storage.find(uri), :stream => true, :buffer_size => ‘4096’
    def find(uri)
      begin
        bucket_and_key = uri.split(':').last
        bucket_name, key = bucket_and_key.split('#')
        env_bucket_name = set_correct_env_bucket_name(bucket_name)
        object = get_object(env_bucket_name, key)
        read_object(object)
      rescue Exception => e
        nil
      end
    end

    # The param uri is present in Document model. Document.identifier
    # The uri has information about the bucket name and key
    # e.g. "urn:openhbx:terms:v1:file_storage:s3:bucket:#{bucket_name}##{key}"
    # The returned object can be streamed by controller
    # e.g. send_data Aws::S3Storage.find(uri), :stream => true, :buffer_size => ‘4096’
    def self.find(uri)
      Aws::S3Storage.new.find(uri)
    end

    private
    def read_object(object)
      object.get.body.read
    end

    def get_object(bucket_name, key)
      @resource.bucket(bucket_name).object(key)
    end

    def set_correct_env_bucket_name(bucket_name)
      bucket_name_segment = bucket_name.split('-')
      if ENV_LIST.include? bucket_name_segment.last && bucket_name_segment.last == aws_env
        return bucket_name
      else
        bucket_name_segment[bucket_name_segment.length - 1] = aws_env
        return bucket_name_segment.join('-')
      end
    end

    def aws_env
      ENV['AWS_ENV'] || "local"
    end

    def hbx_id
      "dchbx"
    end

    def env_bucket_name(bucket_name, h41 = nil)
     h41.present? ? "#{hbx_id}-enroll-aca-internal-artifact-transport-#{aws_env}" : "#{hbx_id}-gluedb-#{bucket_name}-#{aws_env}" 
    end

    def setup
      client=Aws::S3::Client.new
      @resource=Aws::S3::Resource.new(client: client)
    end
  end
end
