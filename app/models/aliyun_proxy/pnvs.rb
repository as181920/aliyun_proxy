module AliyunProxy
  module Pnvs
    END_POINT = "https://dypnsapi.aliyuncs.com".freeze
    API_VERSION = "2017-05-25".freeze

    def self.table_name_prefix
      "aliyun_pnvs_"
    end
  end
end
