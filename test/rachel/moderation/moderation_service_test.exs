defmodule Rachel.Moderation.ModerationServiceTest do
  use Rachel.DataCase, async: true
  alias Rachel.Moderation.ModerationService

  describe "check_content/2" do
    test "allows clean content" do
      assert :ok == ModerationService.check_content("Hello world", :tagline)
    end

    test "rejects content with profanity" do
      assert {:reject, _} = ModerationService.check_content("damn you", :tagline)
    end

    test "rejects content with URLs" do
      assert {:reject, _} = ModerationService.check_content("Visit http://spam.com", :tagline)
    end

    test "rejects content with excessive special characters" do
      assert {:reject, _} = ModerationService.check_content("!!!###$$$%%%", :tagline)
    end

    test "flags suspicious patterns" do
      assert {:flag, _} = ModerationService.check_content("v1agra ch3ap", :tagline)
    end
  end
end
