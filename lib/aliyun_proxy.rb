require "aliyun_proxy/version"

module AliyunProxy
  def self.table_name_prefix
    "aliyun_"
  end
end

require "aliyun_proxy/engine"
