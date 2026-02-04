#include <gtest/gtest.h>

#include "framework/otml/otmldocument.h"

#include <sstream>
#include <string>
#include <string_view>

namespace {

OTMLNodePtr findStyleByTag(const OTMLDocumentPtr& doc, std::string_view tag)
{
    for (const auto& node : doc->children()) {
        if (node->tag() == tag)
            return node;
    }
    return nullptr;
}

} // namespace

TEST(OTMLAlias, ResolvesRootAliases)
{
    const std::string document = R"(
&primaryColor: #112233

TestStyle < UIWidget
  color: $primaryColor
  background-color: $primaryColor
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto style = findStyleByTag(doc, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style);
    EXPECT_EQ("#112233", style->valueAt("color"));
    EXPECT_EQ("#112233", style->valueAt("background-color"));

    const auto& aliases = doc->globalAliases();
    EXPECT_EQ(1u, aliases.size());
    EXPECT_EQ("#112233", aliases.at("primaryColor"));
}

TEST(OTMLAlias, ResolvesNodeScopedAliases)
{
    const std::string document = R"(
&primaryColor: #33AAFF
&secondaryColor: $primaryColor

DerivedPanel < UIWidget
  &panelAccent: $secondaryColor
  padding: $panelAccent
  PanelHeader < UIWidget
    &headerAccent: $panelAccent
    background-color: $headerAccent
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto panel = findStyleByTag(doc, "DerivedPanel < UIWidget");
    ASSERT_NE(nullptr, panel);
    EXPECT_EQ("#33AAFF", panel->valueAt("padding"));

    const auto header = panel->get("PanelHeader < UIWidget");
    ASSERT_NE(nullptr, header);
    EXPECT_EQ("#33AAFF", header->valueAt("background-color"));

    const auto& aliases = doc->globalAliases();
    EXPECT_EQ(2u, aliases.size());
    EXPECT_EQ("#33AAFF", aliases.at("secondaryColor"));
    EXPECT_EQ(aliases.end(), aliases.find("panelAccent"));
    EXPECT_EQ(aliases.end(), aliases.find("headerAccent"));
}
