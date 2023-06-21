# frozen_string_literal: true

# Adapted from `https://github.com/janko/uppy-s3_multipart/blob/master/lib/uppy/s3_multipart/app.rb`.

require "pathname"
require "uppy/s3_multipart"

module Scalient
  module Rails
    class UppyS3MultipartsController < ::Rails.application.config.uppy_s3_multipart.base_controller.safe_constantize
      # `POST /`
      def create
        type = params["type"]
        filename = params["filename"]

        key = key_transform.call(SecureRandom.hex, filename)
        key = [*prefix, key].join("/")

        options = {}

        if type
          options[:content_type] = type
        end

        if filename
          options[:content_disposition] = ContentDisposition.inline(Pathname.new(filename).basename.to_s)
        end

        if is_public
          options[:acl] = "public-read"
        end

        result = client_call(:create_multipart_upload, key: key, **options)

        render json: {uploadId: result.fetch(:upload_id), key: result.fetch(:key)}
      end

      # `GET /:upload_id`
      def show
        upload_id = params.require(:upload_id)
        key = params.require(:key)

        result = client_call(:list_parts, upload_id: upload_id, key: key)

        render json: result.map do |part|
          {PartNumber: part.fetch(:part_number), Size: part.fetch(:size), ETag: part.fetch(:etag)}
        end
      end

      # `GET /:upload_id/batch`
      def batch
        upload_id = params.require(:upload_id)
        key = params.require(:key)
        part_numbers = params.require(:partNumbers).split(",")

        batch = part_numbers.to_h do |part_number|
          result = client_call(:prepare_upload_part, upload_id: upload_id, key: key, part_number: part_number)
          [part_number, result.fetch(:url)]
        end

        render json: {presignedUrls: batch}
      end

      # `GET /:upload_id/:part_number`
      def part_number
        upload_id = params.require(:upload_id)
        key = params.require(:key)
        part_number = params.require(:part_number)

        result = client_call(:prepare_upload_part, upload_id: upload_id, key: key, part_number: part_number)

        render json: {url: result.fetch(:url)}
      end

      # `POST /:upload_id/complete`
      def complete
        upload_id = params.require(:upload_id)
        key = params.require(:key)
        parts = params.require(:parts)

        parts = parts.map do |part|
          begin
            {part_number: part.fetch("PartNumber"), etag: part.fetch("ETag")}
          rescue KeyError
            render json: error_json("At least one part is missing \"PartNumber\" or \"ETag\" field"), status: 400

            return
          end
        end

        client_call(:complete_multipart_upload, upload_id: upload_id, key: key, parts: parts)

        object_url = client_call(:object_url, key: key, public: is_public)

        render json: {location: object_url}
      end

      # `DELETE /:upload_id`
      def destroy
        upload_id = params.require(:upload_id)
        key = params.require(:key)

        begin
          client_call(:abort_multipart_upload, upload_id: upload_id, key: key)
        rescue Aws::S3::Errors::NoSuchUpload
          render json: error_json("Upload doesn't exist for \"key\" parameter"), status: 404

          return
        end

        head :no_content
      end

      def preflight
        head :no_content
      end

      private

      def is_public
        ::Rails.application.config.uppy_s3_multipart.public
      end

      def prefix
        @prefix ||= ::Rails.application.config.uppy_s3_multipart.prefix
      end

      def client
        @client ||= Uppy::S3Multipart::Client.new(bucket: ::Rails.application.config.uppy_s3_multipart.bucket)
      end

      def app_options
        @options ||= ::Rails.application.config.uppy_s3_multipart.options
      end

      def key_transform
        @key_transform ||= ::Rails.application.config.uppy_s3_multipart.key_transform
      end

      def client_call(operation, **options)
        overrides = app_options[operation] || {}
        overrides = overrides.call(request) if overrides.respond_to?(:call)

        options = options.merge(overrides)

        client.send(operation, **options)
      end

      def error_json(message)
        {message: message}
      end
    end
  end
end
