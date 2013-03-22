require 'helper'

describe "RackAffiliates" do
  before :each do
    clear_cookies
  end

  it "should handle empty affiliate info" do
    get '/'

    last_request.env['affiliate.tag'].must_equal nil
    last_request.env['affiliate.from'].must_equal nil
    last_request.env['affiliate.time'].must_equal nil
  end

  it "should set affiliate info from params" do
    Timecop.freeze do
      @time = Time.now
      get '/', {'ref'=>'123', 's'=>'abc'}
    end

    last_request.env['affiliate.tag'].must_equal "123"
    last_request.env['affiliate.from'].must_equal "abc"
    last_request.env['affiliate.time'].must_equal @time.to_i
  end

  it "should save affiliate info in a cookie" do
    Timecop.freeze do
      @time = Time.now
      get '/', {'ref'=>'123', 's'=>'abc'}
    end

    rack_mock_session.cookie_jar["aff_tag"].must_equal "123"
    rack_mock_session.cookie_jar["aff_from"].must_equal "abc"
    rack_mock_session.cookie_jar["aff_time"].must_equal "#{@time.to_i}"
  end

  describe "when cookie exists" do
    before :each do
      @time = Time.now
      clear_cookies
      set_cookie("aff_tag=123")
      set_cookie("aff_from=abc")
      set_cookie("aff_time=#{@time.to_i}")
    end

    it "should restore affiliate info from cookie" do
      Timecop.freeze do
        get '/', {}, 'HTTP_REFERER' => "http://www.bar.com"
      end

      last_request.env['affiliate.tag'].must_equal "123"
      last_request.env['affiliate.from'].must_equal "abc"
      last_request.env['affiliate.time'].must_equal @time.to_i
    end

    it 'should not update existing cookie' do
      Timecop.freeze(60*60*24) do #1 day later
        get '/', {}, 'HTTP_REFERER' => "http://www.bar.com"
      end

      last_request.env['affiliate.tag'].must_equal "123"
      last_request.env['affiliate.from'].must_equal "abc"

      # should not change timestamp of older cookie
      last_request.env['affiliate.time'].must_equal @time.to_i

      rack_mock_session.cookie_jar["aff_tag"].must_equal "123"
      rack_mock_session.cookie_jar["aff_from"].must_equal "abc"
      rack_mock_session.cookie_jar["aff_time"].must_equal "#{@time.to_i}"
    end

    it "should use newer affiliate from params" do
      Timecop.freeze(60*60*24) do #1 day later
        @new_time = Time.now
        get '/', {'ref' => 456, 's' => 'def'}
      end

      rack_mock_session.cookie_jar["aff_tag"].must_equal "456"
      rack_mock_session.cookie_jar["aff_from"].must_equal "def"
      rack_mock_session.cookie_jar["aff_time"].must_equal "#{@new_time.to_i}"

      last_request.env['affiliate.tag'].must_equal "456"
      last_request.env['affiliate.from'].must_equal "def"
      last_request.env['affiliate.time'].must_equal @new_time.to_i
    end
  end
end
