require "test_helper"
require 'ruby-prof'

class CachedTest < MiniTest::Spec
  # TODO: also test with feature(Cached)

  module Model
    Song  = Struct.new(:title, :composer)
    Album = Struct.new(:name, :songs, :artist)
    Artist = Struct.new(:name, :hidden_taste)
  end

  class SongRepresenter < Representable::Decorator
    include Representable::Hash
    feature Representable::Cached

    property :title, render_filter: lambda { |input, options| "#{input}:#{options[:options][:user_options]}" }
    property :composer, class: Model::Artist do
      property :name
    end
  end

  class AlbumRepresenter < Representable::Decorator
    include Representable::Hash
    include Representable::Cached

    property :name
    collection :songs, decorator: SongRepresenter, class: Model::Song
  end


  describe "serialization" do
    let (:album_hash) { {"name"=>"Louder And Even More Dangerous", "songs"=>[{"title"=>"Southbound:{:volume=>10}"}, {"title"=>"Jailbreak:{:volume=>10}"}]} }

    let (:song) { Model::Song.new("Jailbreak") }
    let (:song2) { Model::Song.new("Southbound") }
    let (:album) { Model::Album.new("Live And Dangerous", [song, song2, Model::Song.new("Emerald")]) }
    let (:representer) { AlbumRepresenter.new(album) }

    it do
      album2 = Model::Album.new("Louder And Even More Dangerous", [song2, song])

      # makes sure options are passed correctly.
      representer.to_hash(user_options: {volume: 9}).must_equal({"name"=>"Live And Dangerous",
        "songs"=>[{"title"=>"Jailbreak:{:volume=>9}"}, {"title"=>"Southbound:{:volume=>9}"}, {"title"=>"Emerald:{:volume=>9}"}]}) # called in Deserializer/Serializer

      # representer becomes reusable as it is stateless.
      # representer.update!(album2)

      # makes sure options are passed correctly.
      # representer.to_hash(volume:10).must_equal(album_hash)
    end

    # profiling
    it do
      representer.to_hash

     RubyProf.start
        representer.to_hash
      res = RubyProf.stop

      printer = RubyProf::FlatPrinter.new(res)

      data = StringIO.new
      printer.print(data)
      data = data.string

      printer.print(STDOUT)

      # 3 songs get decorated.
      data.must_match "3   Representable::Function::Decorate#call"
      # 3 nested decorator is instantiated for 3 Songs, though.
      data.must_match "3   <Class::Representable::Decorator>#prepare"
      # no Binding is instantiated at runtime.
      data.wont_match "Representable::Binding#initialize"
      # 2 mappers for Album, Song
      # data.must_match "2   Representable::Mapper::Methods#initialize"
      # title, songs, 3x title, composer
      data.must_match "8   Representable::Binding#render_pipeline"
      data.wont_match "render_functions"
      data.wont_match "Representable::Binding::Factories#render_functions"
    end
  end


  describe "deserialization" do
    let (:album_hash) {
      {
        "name"=>"Louder And Even More Dangerous",
        "songs"=>[
          {"title"=>"Southbound", "composer"=>{"name"=>"Lynott"}},
          {"title"=>"Jailbreak", "composer"=>{"name"=>"Phil Lynott"}},
          {"title"=>"Emerald"}
        ]
      }
    }

    it do
      album = Model::Album.new

      AlbumRepresenter.new(album).from_hash(album_hash)

      album.songs.size.must_equal 3
      album.name.must_equal "Louder And Even More Dangerous"
      album.songs[0].title.must_equal "Southbound"
      album.songs[0].composer.name.must_equal "Lynott"
      album.songs[1].title.must_equal "Jailbreak"
      album.songs[1].composer.name.must_equal "Phil Lynott"
      album.songs[2].title.must_equal "Emerald"
      album.songs[2].composer.must_equal nil

      # TODO: test options.
    end

    it "xxx" do
      representer = AlbumRepresenter.new(Model::Album.new)
      representer.from_hash(album_hash)

      RubyProf.start
        # puts "#{representer.class.representable_attrs.get(:songs).representer_module.representable_attrs.inspect}"
        representer.from_hash(album_hash)
      res = RubyProf.stop

      printer = RubyProf::FlatPrinter.new(res)

      data = StringIO.new
      printer.print(data)
      data = data.string

      # only 2 nested decorators are instantiated, Song, and Artist.
      data.must_match "5   <Class::Representable::Decorator>#prepare"
      # a total of 5 properties in the object graph.
      data.wont_match "Representable::Binding#initialize"


      data.wont_match "parse_functions" # no pipeline creation.
      data.must_match "10   Representable::Binding#parse_pipeline"
      # three mappers for Album, Song, composer
      # data.must_match "3   Representable::Mapper::Methods#initialize"
      # # 6 deserializers as the songs collection uses 2.
      # data.must_match "6   Representable::Deserializer#initialize"
      # # one populater for every property.
      # data.must_match "5   Representable::Populator#initialize"
      # printer.print(STDOUT)
    end
  end
end