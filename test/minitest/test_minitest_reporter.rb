require "minitest/autorun"
require "minitest/metametameta"

class TestMinitestReporter < Minitest::Test

  attr_accessor :r, :io

  class ReporterExtension < Minitest::Reporter
    def print_start
      io.puts "Extension start with arguments: #{options[:args]}"
    end

    def print_record result
      io.puts "Extension record result: #{result.result_code}"
    end

    def print_report time, failures, errors, skips
      io.puts "Extension report:"
      format = "%d runs, %d assertions, %d failures, %d errors, %d skips"
      summary = format % [count, self.assertions, failures, errors, skips]

      io.puts
      io.puts summary
    end
  end

  def setup
    self.io = StringIO.new("")
    self.r  = Minitest::Reporter.new io
  end

  def error_test
    unless defined? @et then
      @et = Minitest::Test.new(:woot)
      @et.failures << Minitest::UnexpectedError.new(begin
                                                      raise "no"
                                                    rescue => e
                                                      e
                                                    end)
    end
    @et
  end

  def fail_test
    unless defined? @ft then
      @ft = Minitest::Test.new(:woot)
      @ft.failures <<   begin
                          raise Minitest::Assertion, "boo"
                        rescue Minitest::Assertion => e
                          e
                        end
    end
    @ft
  end

  def passing_test
    @pt ||= Minitest::Test.new(:woot)
  end

  def skip_test
    unless defined? @st then
      @st = Minitest::Test.new(:woot)
      @st.failures << Minitest::Skip.new
    end
    @st
  end

  def test_passed_eh_empty
    assert r.passed?
  end

  def test_passed_eh_failure
    r.results << fail_test

    refute r.passed?
  end

  def test_passed_eh_error
    r.results << error_test

    refute r.passed?
  end

  def test_passed_eh_skipped
    r.results << skip_test

    assert r.passed?
  end

  def test_start
    r.start

    exp = "Run options: \n\n# Running:\n\n"

    assert_equal exp, io.string
  end

  def test_record_pass
    r.record passing_test

    assert_equal ".", io.string
    assert_empty r.results
    assert_equal 1, r.count
    assert_equal 0, r.assertions
  end

  def test_record_fail
    r.record fail_test

    assert_equal "F", io.string
    assert_equal [fail_test], r.results
    assert_equal 1, r.count
    assert_equal 0, r.assertions
  end

  def test_record_error
    r.record error_test

    assert_equal "E", io.string
    assert_equal [error_test], r.results
    assert_equal 1, r.count
    assert_equal 0, r.assertions
  end

  def test_record_skip
    r.record skip_test

    assert_equal "S", io.string
    assert_equal [skip_test], r.results
    assert_equal 1, r.count
    assert_equal 0, r.assertions
  end

  def normalize_output output
    output.sub!(/Finished in .*/, "Finished in 0.00")
    output.sub!(/Loaded suite .*/, 'Loaded suite blah')

    output.gsub!(/ = \d+.\d\d s = /, ' = 0.00 s = ')
    output.gsub!(/0x[A-Fa-f0-9]+/, '0xXXX')
    output.gsub!(/ +$/, '')

    if windows? then
      output.gsub!(/\[(?:[A-Za-z]:)?[^\]:]+:\d+\]/, '[FILE:LINE]')
      output.gsub!(/^(\s+)(?:[A-Za-z]:)?[^:]+:\d+:in/, '\1FILE:LINE:in')
    else
      output.gsub!(/\[[^\]:]+:\d+\]/, '[FILE:LINE]')
      output.gsub!(/^(\s+)[^:]+:\d+:in/, '\1FILE:LINE:in')
    end

    output
  end

  def test_report_empty
    r.start
    r.report

    exp = clean <<-EOM
      Run options:

      # Running:



      Finished in 0.00

      0 runs, 0 assertions, 0 failures, 0 errors, 0 skips
    EOM


    assert_equal exp, normalize_output(io.string)
  end

  def test_report_passing
    r.start
    r.record passing_test
    r.report

    exp = clean <<-EOM
      Run options:

      # Running:

      .

      Finished in 0.00

      1 runs, 0 assertions, 0 failures, 0 errors, 0 skips
    EOM


    assert_equal exp, normalize_output(io.string)
  end

  def test_report_failure
    r.start
    r.record fail_test
    r.report

    exp = clean <<-EOM
      Run options:

      # Running:

      F

      Finished in 0.00

        1) Failure:
      Minitest::Test#woot [FILE:LINE]:
      boo

      1 runs, 0 assertions, 1 failures, 0 errors, 0 skips
    EOM


    assert_equal exp, normalize_output(io.string)
  end

  def test_report_error
    r.start
    r.record error_test
    r.report

    exp = clean <<-EOM
      Run options:

      # Running:

      E

      Finished in 0.00

        1) Error:
      Minitest::Test#woot:
      RuntimeError: no
          FILE:LINE:in `error_test'
          FILE:LINE:in `test_report_error'

      1 runs, 0 assertions, 0 failures, 1 errors, 0 skips
    EOM

    assert_equal exp, normalize_output(io.string)
  end

  def test_report_skipped
    r.start
    r.record skip_test
    r.report

    exp = clean <<-EOM
      Run options:

      # Running:

      S

      Finished in 0.00

      1 runs, 0 assertions, 0 failures, 0 errors, 1 skips
    EOM

    assert_equal exp, normalize_output(io.string)
  end

  def test_report_extension
    e = ReporterExtension.new io
    e.start
    e.record skip_test
    e.report

    exp = clean <<-EOM
      Extension start with arguments:
      Extension record result: S
      Extension report:

      1 runs, 0 assertions, 0 failures, 0 errors, 1 skips
    EOM

    assert_equal exp, normalize_output(io.string)
  end
end
