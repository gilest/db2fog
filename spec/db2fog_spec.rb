require File.dirname(__FILE__) + '/spec_helper'

class Person < ActiveRecord::Base
end

describe DB2Fog do

  let(:storage_dir) { File.join(File.dirname(__FILE__), "storage", "db2fog-test") }

  before :each do
    FileUtils.rm_r(storage_dir) if File.directory?(storage_dir)
    FileUtils.mkdir_p(storage_dir)
  end

  def load_schema
    run_query_system(DBQueries[:create_schema])
  end

  def backup_files
    Dir.entries(storage_dir).select { |f| f[0,1] != "."}.sort
  end

  describe "backup()" do
    it 'can save a backup' do
      db2fog = DB2Fog.new
      # load_schema
      Person.create!(:name => "Baxter")

      Timecop.travel(Time.utc(2011, 7, 23, 14, 10, 0)) do
        db2fog.backup
      end

      backup_files.should == ["dump-db2fog_test-201107231410.sql.gz", "most-recent-dump-db2fog_test.txt"]
    end

    it 'can save two backups' do
      db2fog = DB2Fog.new
      # load_schema
      Person.create!(:name => "Baxter")

      Timecop.travel(Time.utc(2011, 7, 23, 14, 10, 0)) do
        db2fog.backup
      end

      Timecop.travel(Time.utc(2011, 7, 24, 14, 10, 0)) do
        db2fog.backup
      end

      backup_files.should == ["dump-db2fog_test-201107231410.sql.gz","dump-db2fog_test-201107241410.sql.gz","most-recent-dump-db2fog_test.txt"]
    end

    it 'can record the filename of the most recent backup' do
      db2fog = DB2Fog.new
      # load_schema
      Person.create!(:name => "Baxter")

      Timecop.travel(Time.utc(2011, 7, 23, 12, 10, 0)) { db2fog.backup }
      Timecop.travel(Time.utc(2011, 7, 23, 14, 10, 0)) { db2fog.backup }

      latest = File.join(storage_dir, "most-recent-dump-db2fog_test.txt")
      File.read(latest).should == "dump-db2fog_test-201107231410.sql.gz"
    end
  end

  describe "restore()" do
    it 'can save and restore a backup' do
      db2fog = DB2Fog.new
      # load_schema
      Person.create!(:name => "Baxter")
      db2fog.backup
      # load_schema
      db2fog.restore
      Person.find_by_name("Baxter").should_not be_nil
    end
  end

  describe "clean()" do
    it 'can remove old backups' do
      db2fog = DB2Fog.new
      # load_schema
      Person.create!(:name => "Baxter")

      # keep 1 backup per week
      Timecop.travel(Time.utc(2011, 6, 23, 14, 10, 0)) { db2fog.backup }
      Timecop.travel(Time.utc(2011, 6, 24, 14, 10, 0)) { db2fog.backup }

      # keep 1 backup per day
      Timecop.travel(Time.utc(2011, 7, 20, 14, 10, 0)) { db2fog.backup }
      Timecop.travel(Time.utc(2011, 7, 20, 18, 10, 0)) { db2fog.backup }
      Timecop.travel(Time.utc(2011, 7, 20, 23, 10, 0)) { db2fog.backup }

      # keep all backups from past 24 hours
      Timecop.travel(Time.utc(2011, 7, 23, 12, 10, 0)) { db2fog.backup }
      Timecop.travel(Time.utc(2011, 7, 23, 14, 10, 0)) { db2fog.backup }

      # clean up
      Timecop.travel(Time.utc(2011, 7, 23, 14, 10, 0)) { db2fog.clean }

      backup_files.should == [
        "dump-db2fog_test-201106231410.sql.gz",
        "dump-db2fog_test-201107201410.sql.gz",
        "dump-db2fog_test-201107231210.sql.gz",
        "dump-db2fog_test-201107231410.sql.gz",
        "most-recent-dump-db2fog_test.txt"
      ]
    end

    it 'only cleans files created by db2fog' do
      File.open("#{storage_dir}/foo.txt","wb") { |f| f.write "hello"}
      db2fog = DB2Fog.new
      # load_schema
      Person.create!(:name => "Baxter")

      # clean up
      Timecop.travel(Time.utc(2011, 7, 23, 14, 10, 0)) { db2fog.clean }

      backup_files.should == [ "foo.txt" ]
    end
  end
end