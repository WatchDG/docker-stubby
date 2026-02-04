package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
)

func getEnv(key, defaultValue string) string {
	if val := os.Getenv(key); val != "" {
		return val
	}
	return defaultValue
}

func buildList(prefix string, defaultFirst string) string {
	var items []string
	i := 0
	for i <= 99 {
		key := fmt.Sprintf("%s__%d", prefix, i)
		val := os.Getenv(key)
		if i == 0 && val == "" && defaultFirst != "" {
			val = defaultFirst
		}
		if val != "" {
			items = append(items, fmt.Sprintf("- %s", val))
		}
		i++
	}
	if len(items) == 0 && defaultFirst != "" {
		return fmt.Sprintf("- %s", defaultFirst)
	}
	return strings.Join(items, "\n")
}

func buildUpstreamList() string {
	var blocks []string
	i := 0
	for i <= 99 {
		addressKey := fmt.Sprintf("STUBBY__UPSTREAM_RECURSIVE_SERVERS__%d__ADDRESS_DATA", i)
		addressData := os.Getenv(addressKey)
		
		if i == 0 && addressData == "" {
			addressData = "194.242.2.2"
		}
		
		if addressData != "" {
			block := fmt.Sprintf("- address_data: %s", addressData)
			
			tlsPortKey := fmt.Sprintf("STUBBY__UPSTREAM_RECURSIVE_SERVERS__%d__TLS_PORT", i)
			tlsPort := os.Getenv(tlsPortKey)
			if tlsPort != "" {
				block += fmt.Sprintf("\n  tls_port: %s", tlsPort)
			} else if i == 0 {
				block += "\n  tls_port: 853"
			}
			
			tlsAuthKey := fmt.Sprintf("STUBBY__UPSTREAM_RECURSIVE_SERVERS__%d__TLS_AUTH_NAME", i)
			tlsAuth := os.Getenv(tlsAuthKey)
			if tlsAuth != "" {
				block += fmt.Sprintf("\n  tls_auth_name: \"%s\"", tlsAuth)
			} else if i == 0 {
				block += "\n  tls_auth_name: \"dns.mullvad.net\""
			}
			
			blocks = append(blocks, block)
		}
		i++
	}
	
	if len(blocks) == 0 {
		return "- address_data: 194.242.2.2\n  tls_port: 853\n  tls_auth_name: \"dns.mullvad.net\""
	}
	
	return strings.Join(blocks, "\n")
}

func buildDNSSECTrustAnchors() string {
	var anchors []string
	i := 0
	for i <= 99 {
		key := fmt.Sprintf("STUBBY__DNSSEC_TRUST_ANCHORS__%d", i)
		if val := os.Getenv(key); val != "" {
			anchors = append(anchors, fmt.Sprintf("  - \"%s\"", val))
		}
		i++
	}
	if len(anchors) == 0 {
		return ""
	}
	return "dnssec_trust_anchors:\n" + strings.Join(anchors, "\n")
}

func main() {
	template := getEnv("TEMPLATE", "/etc/stubby/stubby.yml.template")
	conf := getEnv("CONF", "/etc/stubby/stubby.yml")

	data, err := ioutil.ReadFile(template)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error reading template: %v\n", err)
		os.Exit(1)
	}

	content := string(data)

	replacements := map[string]string{
		"__LOG_LEVEL__":                      getEnv("STUBBY__LOG_LEVEL", "GETDNS_LOG_ERR"),
		"__IDLE_TIMEOUT__":                   getEnv("STUBBY__IDLE_TIMEOUT", "10000"),
		"__EDNS_CLIENT_SUBNET_PRIVATE__":     getEnv("STUBBY__EDNS_CLIENT_SUBNET_PRIVATE", "1"),
		"__ROUND_ROBIN_UPSTREAMS__":          getEnv("STUBBY__ROUND_ROBIN_UPSTREAMS", "0"),
		"__TLS_AUTHENTICATION__":             getEnv("STUBBY__TLS_AUTHENTICATION", "GETDNS_AUTHENTICATION_REQUIRED"),
		"__TLS_QUERY_PADDING_BLOCKSIZE__":    getEnv("STUBBY__TLS_QUERY_PADDING_BLOCKSIZE", "256"),
		"__TLS_MIN_VERSION__":                getEnv("STUBBY__TLS_MIN_VERSION", "GETDNS_TLS1_2"),
		"__TLS_MAX_VERSION__":                getEnv("STUBBY__TLS_MAX_VERSION", "GETDNS_TLS1_3"),
		"__DNSSEC__":                         getEnv("STUBBY__DNSSEC", "GETDNS_EXTENSION_TRUE"),
		"__DNSSEC_RETURN_STATUS__":           getEnv("STUBBY__DNSSEC_RETURN_STATUS", "GETDNS_EXTENSION_TRUE"),
		"__DNS_TRANSPORT_LIST__":             buildList("STUBBY__DNS_TRANSPORT_LIST", "GETDNS_TRANSPORT_TLS"),
		"__LISTEN_ADDRESSES__":               buildList("STUBBY__LISTEN_ADDRESSES", "0.0.0.0@8053"),
		"__UPSTREAM_RECURSIVE_SERVERS__":     buildUpstreamList(),
	}

	for placeholder, value := range replacements {
		if placeholder == "__DNS_TRANSPORT_LIST__" || placeholder == "__LISTEN_ADDRESSES__" || placeholder == "__UPSTREAM_RECURSIVE_SERVERS__" {
			re := regexp.MustCompile(`(?m)^(\s*)` + regexp.QuoteMeta(placeholder) + `$`)
			content = re.ReplaceAllStringFunc(content, func(match string) string {
				indent := regexp.MustCompile(`^(\s*)` + regexp.QuoteMeta(placeholder) + `$`).FindStringSubmatch(match)[1]
				lines := strings.Split(value, "\n")
				var indentedLines []string
				for i, line := range lines {
					if i == 0 {
						indentedLines = append(indentedLines, indent+line)
					} else if line != "" {
						indentedLines = append(indentedLines, indent+line)
					} else {
						indentedLines = append(indentedLines, "")
					}
				}
				return strings.Join(indentedLines, "\n")
			})
		} else {
			content = strings.ReplaceAll(content, placeholder, value)
		}
	}

	trustAnchors := buildDNSSECTrustAnchors()
	if trustAnchors != "" {
		content = regexp.MustCompile(`(?m)^# __DNSSEC_TRUST_ANCHORS__$`).ReplaceAllString(content, trustAnchors)
	} else {
		content = regexp.MustCompile(`(?m)^# __DNSSEC_TRUST_ANCHORS__$\n?`).ReplaceAllString(content, "")
	}

	if err := os.MkdirAll(filepath.Dir(conf), 0755); err != nil {
		fmt.Fprintf(os.Stderr, "Error creating config directory: %v\n", err)
		os.Exit(1)
	}

	if err := ioutil.WriteFile(conf, []byte(content), 0644); err != nil {
		fmt.Fprintf(os.Stderr, "Error writing config: %v\n", err)
		os.Exit(1)
	}

	args := []string{"/usr/bin/stubby", "-C", conf, "-l"}
	if err := syscall.Exec("/usr/bin/stubby", args, os.Environ()); err != nil {
		fmt.Fprintf(os.Stderr, "Error executing stubby: %v\n", err)
		os.Exit(1)
	}
}
