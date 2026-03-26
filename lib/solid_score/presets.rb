# frozen_string_literal: true

module SolidScore
  module Presets
    RAILS = {
      paths: %w[
        app/models
        app/controllers
        app/services
        app/jobs
        app/mailers
        app/forms
        app/presenters
        app/serializers
        lib
      ],
      exclude: %w[
        spec/**
        test/**
        vendor/**
        db/**
        tmp/**
      ],
      weights: {
        srp: 0.25,
        ocp: 0.15,
        lsp: 0.10,
        isp: 0.20,
        dip: 0.30
      },
      dip_whitelist: %w[
        Rails
        Logger
        FileUtils
        Pathname
        URI
        JSON
        CSV
        Net::HTTP
        OpenSSL
        Digest
        SecureRandom
        ERB
        ActionMailer
        ActiveJob
        ActiveStorage
      ]
    }.freeze

    REGISTRY = {
      "rails" => RAILS
    }.freeze

    def self.fetch(name)
      REGISTRY.fetch(name.to_s) do
        raise ArgumentError, "Unknown preset: #{name}. Available: #{REGISTRY.keys.join(', ')}"
      end
    end

    def self.available
      REGISTRY.keys
    end
  end
end
