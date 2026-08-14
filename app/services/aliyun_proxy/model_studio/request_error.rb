module AliyunProxy
  module ModelStudio
    class RequestError < Error
      attr_reader :request_id, :status

      def initialize(message, status: nil, request_id: nil)
        @status = status
        @request_id = request_id
        super(message)
      end
    end
  end
end
