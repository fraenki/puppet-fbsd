# frozen_string_literal: true

require 'spec_helper'

describe 'fbsd::routing' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      context 'when declared outside the module' do
        it { is_expected.to compile.and_raise_error(%r{private}) }
      end
    end
  end
end
