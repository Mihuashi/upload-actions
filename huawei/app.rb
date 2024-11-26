# frozen_string_literal: true

require 'openssl'
require 'httparty'
require 'json'
require 'active_support/all'


CLIENT_ID = ENV['INPUT_CLIENT_ID']
if CLIENT_ID.blank?
  puts 'INPUT_CLIENT_ID is blank'
  exit 1
end
CLIENT_SECRET = ENV['INPUT_CLIENT_SECRET']
if CLIENT_SECRET.blank?
  puts 'INPUT_CLIENT_SECRET is blank'
  exit 1
end
APP_ID = ENV['INPUT_APP_ID']
if APP_ID.blank?
  puts 'INPUT_APP_ID is blank'
  exit 1
end
APK_FILE_PATH = ENV['INPUT_APK_FILE_PATH']
if APK_FILE_PATH.blank?
  puts 'INPUT_APK_FILE_PATH is blank'
  exit 1
end
UPDATE_DESC = ENV['INPUT_UPDATE_DESC']
if UPDATE_DESC.blank?
  puts 'INPUT_UPDATE_DESC is blank'
  exit 1
end
ONLINE_TIME = ENV['INPUT_ONLINE_TIME']

ONLINE_TIME_FORMAT = '%Y-%m-%d %H:%M:%S'
begin
  Time.strptime(ONLINE_TIME, ONLINE_TIME_FORMAT) unless ONLINE_TIME.blank?
rescue ArgumentError
  puts "INPUT_ONLINE_TIME format error, should be like: #{ONLINE_TIME_FORMAT}"
  exit 1
end

puts "CLIENT_ID: #{CLIENT_ID} APP_ID: #{APP_ID} APK_FILE_PATH: #{APK_FILE_PATH} UPDATE_DESC: #{UPDATE_DESC} ONLINE_TIME: #{ONLINE_TIME}"
HUAWEI_BASE_URL = 'https://connect-api.cloud.huawei.com'

def get_access_token
  return @access_token if @access_token

  url = "#{HUAWEI_BASE_URL}/api/oauth2/v1/token"
  params = {
    client_id: CLIENT_ID,
    client_secret: CLIENT_SECRET,
    grant_type: 'client_credentials'
  }
  response = HTTParty.post(url, body: params.to_json, headers: { 'Content-Type' => 'application/json' })
  @access_token = response['access_token']
end

# 查询应用信息
# https://connect-api.cloud.huawei.com/api/publish/v2/app-info
def get_app_info
  url = "#{HUAWEI_BASE_URL}/api/publish/v2/app-info"
  params = {
    appId: APP_ID,
    lang: 'zh-CN'
  }
  headers = {
    Authorization: "Bearer #{get_access_token}",
    client_id: CLIENT_ID
  }
  HTTParty.get(url, query: params, headers: headers)
end

# 获取文件上传地址
# https://connect-api.cloud.huawei.com/api/publish/v2/upload-url/for-obs
def get_upload_url(apk_file)
  url = "#{HUAWEI_BASE_URL}/api/publish/v2/upload-url/for-obs"
  headers = {
    Authorization: "Bearer #{get_access_token}",
    client_id: CLIENT_ID
  }
  params = {
    appId: APP_ID,
    fileName: File.basename(apk_file),
    contentLength: File.size(apk_file),
    sha256: OpenSSL::Digest::SHA256.hexdigest(File.read(apk_file))
  }
  response = HTTParty.get(url, query: params, headers: headers)
  response['urlInfo']
end

# 上传文件
def upload_file(apk_file, url_info)
  url = url_info['url']
  headers = url_info['headers']
  method = url_info['method'].downcase
  HTTParty.send(method, url, body: File.read(apk_file), headers: headers)
end


# 更新应用文件信息
# https://connect-api.cloud.huawei.com/api/publish/v2/app-file-info
def update_app_file_info(apk_file)
  url_info = get_upload_url(apk_file)
  upload_file_info = upload_file(apk_file, url_info)
  puts "upload_file_info: #{upload_file_info.success?}"
  url = "#{HUAWEI_BASE_URL}/api/publish/v2/app-file-info"
  query = {
    appId: APP_ID,
    releaseType: 1
  }
  headers = {
    Authorization: "Bearer #{get_access_token}",
    client_id: CLIENT_ID,
    'Content-Type': 'application/json'
  }
  body = {
    lang: 'zh-CN',
    fileType: 5,
    files: [{ fileName: File.basename(apk_file), fileDestUrl: url_info['objectId'] }]
  }
  HTTParty.put(url, query: query, headers: headers, body: body.to_json)
end

# 更新语言描述信息
# https://connect-api.cloud.huawei.com/api/publish/v2/app-language-info
def update_language_info(update_desc)
  url = "#{HUAWEI_BASE_URL}/api/publish/v2/app-language-info"
  app_info = get_app_info
  headers = {
    Authorization: "Bearer #{get_access_token}",
    client_id: CLIENT_ID
  }
  query = {
    appId: APP_ID,
    releaseType: 1
  }
  language_info = app_info['languages'][0]
  body = {
    lang: 'zh-CN',
    appName: language_info['appName'],
    appDesc: language_info['appDesc'],
    briefInfo: language_info['briefInfo'],
    newFeatures: update_desc
  }
  # 修复了已知的Bug。
  HTTParty.put(url, query: query, headers: headers, body: body)
end

# 提交发布
# https://connect-api.cloud.huawei.com/api/publish/v2/app-submit
def submit_release(sche_online_time)
  url = "#{HUAWEI_BASE_URL}/api/publish/v2/app-submit"
  headers = {
    Authorization: "Bearer #{get_access_token}",
    client_id: CLIENT_ID
  }
  time = Time.parse(sche_online_time).getlocal('+08:00')
  release_time = time.strftime('%Y-%m-%dT%H:%M:%S%z')
  query = {
    appId: APP_ID,
    releaseType: 1
  }
  unless sche_online_time.blank?
    query[:releaseTime] = release_time
  end
  HTTParty.post(url, query: query, headers: headers)
end

# update_app_file_info
update_app_file_info_result = update_app_file_info(APK_FILE_PATH)
puts "update_app_file_info result: #{update_app_file_info_result}"
update_language_info_result = update_language_info(UPDATE_DESC)
puts "update_language_info result: #{update_language_info_result}"
submit_release_result = submit_release(ONLINE_TIME)
puts "submit_release result: #{submit_release_result}"