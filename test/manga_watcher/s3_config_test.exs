defmodule MangaWatcher.S3ConfigTest do
  use ExUnit.Case

  alias MangaWatcher.S3Config

  describe "endpoint_options/1" do
    test "keeps endpoint host and port separate for ExAws" do
      assert S3Config.endpoint_options("http://localhost:3900") == [
               scheme: "http://",
               host: "localhost",
               port: 3900,
               region: "garage"
             ]
    end

    test "sets Garage as the S3 signing region" do
      original_s3_config = Application.get_env(:ex_aws, :s3)

      on_exit(fn ->
        if original_s3_config do
          Application.put_env(:ex_aws, :s3, original_s3_config)
        else
          Application.delete_env(:ex_aws, :s3)
        end
      end)

      Application.put_env(:ex_aws, :s3, S3Config.endpoint_options("http://localhost:3900"))

      assert %{region: "garage"} =
               ExAws.Config.new(:s3, access_key_id: "test", secret_access_key: "test")
    end

    test "builds the expected ExAws URL for local S3 endpoints" do
      original_s3_config = Application.get_env(:ex_aws, :s3)

      on_exit(fn ->
        if original_s3_config do
          Application.put_env(:ex_aws, :s3, original_s3_config)
        else
          Application.delete_env(:ex_aws, :s3)
        end
      end)

      Application.put_env(:ex_aws, :s3, S3Config.endpoint_options("http://localhost:3900"))

      config = ExAws.Config.new(:s3, access_key_id: "test", secret_access_key: "test")

      operation = %{path: "/default-bucket/damn_reincarnation.png", params: %{}}

      assert ExAws.Request.Url.build(operation, config) ==
               "http://localhost:3900/default-bucket/damn_reincarnation.png"
    end

    test "raises for endpoints without an http scheme" do
      assert_raise ArgumentError, ~r/S3_ENDPOINT must be a URL/, fn ->
        S3Config.endpoint_options("localhost:3900")
      end
    end
  end
end
