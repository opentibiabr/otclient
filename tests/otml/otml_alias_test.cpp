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

TEST(OTMLAlias, CircularReferenceDetection)
{
    // Test direct circular reference: &a: $b and &b: $a
    const std::string document = R"(
&a: $b
&b: $a

TestStyle < UIWidget
  value: $a
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto style = findStyleByTag(doc, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style);
    // Circular reference should not resolve
    EXPECT_EQ("$a", style->valueAt("value"));
}

TEST(OTMLAlias, IndirectCircularReferenceDetection)
{
    // Test indirect circular reference: &a: $b, &b: $c, &c: $a
    const std::string document = R"(
&a: $b
&b: $c
&c: $a

TestStyle < UIWidget
  value: $b
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto style = findStyleByTag(doc, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style);
    // Circular reference should not resolve
    EXPECT_EQ("$b", style->valueAt("value"));
}

TEST(OTMLAlias, UndefinedVariableReference)
{
    const std::string document = R"(
&definedVar: #123456

TestStyle < UIWidget
  color: $undefinedVar
  background: $definedVar
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto style = findStyleByTag(doc, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style);
    // Undefined variable should not resolve
    EXPECT_EQ("$undefinedVar", style->valueAt("color"));
    // Defined variable should resolve
    EXPECT_EQ("#123456", style->valueAt("background"));
}

TEST(OTMLAlias, EmptyVariableName)
{
    // Test empty variable name in definition: &: value
    const std::string document1 = R"(
&: #ABCDEF

TestStyle < UIWidget
  color: test
)";

    std::istringstream stream1(document1);
    const auto doc1 = OTMLDocument::parse(stream1, "otml_alias_test");

    const auto style1 = findStyleByTag(doc1, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style1);
    EXPECT_EQ("test", style1->valueAt("color"));

    // Empty variable name should not be added to aliases
    const auto& aliases1 = doc1->globalAliases();
    EXPECT_EQ(0u, aliases1.size());
}

TEST(OTMLAlias, EmptyVariableReference)
{
    // Test empty variable reference: $
    const std::string document = R"(
&validVar: #112233

TestStyle < UIWidget
  color: $
  background: $validVar
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto style = findStyleByTag(doc, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style);
    // Empty variable reference should not resolve
    EXPECT_EQ("$", style->valueAt("color"));
    // Valid variable should resolve
    EXPECT_EQ("#112233", style->valueAt("background"));
}

TEST(OTMLAlias, MalformedVariableSyntax)
{
    // Test various malformed syntax scenarios
    const std::string document = R"(
&: 
& : value
&  : spaced

TestStyle < UIWidget
  value: test
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto style = findStyleByTag(doc, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style);
    EXPECT_EQ("test", style->valueAt("value"));

    // Malformed variables should not be added to aliases
    const auto& aliases = doc->globalAliases();
    EXPECT_EQ(0u, aliases.size());
}

TEST(OTMLAlias, UndefinedChainedVariableReference)
{
    // Test chain where intermediate variable is undefined
    const std::string document = R"(
&first: $second

TestStyle < UIWidget
  value: $first
)";

    std::istringstream stream(document);
    const auto doc = OTMLDocument::parse(stream, "otml_alias_test");

    const auto style = findStyleByTag(doc, "TestStyle < UIWidget");
    ASSERT_NE(nullptr, style);
    // Chain with undefined variable should not resolve
    EXPECT_EQ("$first", style->valueAt("value"));
}
