"""Generate docs/architecture.drawio for the On-premises hybrid storage demo.

Mirrors the AWS Cloud Quest reference layout: on-premises Application/User/Backup
servers connect over standard protocols to a local Storage Gateway cache, which
replicates over a VPN (optionally a dedicated Direct Connect network) to the
AWS-managed Storage Gateway service. That service is backed by a "Storage
Services" group (S3, S3 Glacier, EBS, EFS) and observed by a "Management and
Monitoring" group (CloudWatch, SNS notifications, AWS Backup).
"""

import os

import drawpyo

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "..", "docs")

AWS4_BASE = (
    "sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;"
    "strokeColor=none;dashed=0;verticalLabelPosition=bottom;verticalAlign=top;"
    "align=center;html=1;fontSize=11;fontStyle=0;aspect=fixed;pointerEvents=1;"
)

GROUP_BASE = (
    "sketch=0;outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontSize=12;"
    "fontStyle=0;pointerEvents=0;collapsible=0;recursiveResize=0;"
)


def aws_style(icon_name, fill_color):
    return f"{AWS4_BASE}fillColor={fill_color};shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{icon_name};"


def add_node(page, name, x, y, icon_name, fill_color, width=64, height=64, parent=None):
    kwargs = {"page": page, "value": name}
    if parent is not None:
        kwargs["parent"] = parent
        kwargs["position_rel_to_parent"] = (x, y)
    else:
        kwargs["position"] = (x, y)
    node = drawpyo.diagram.Object(**kwargs)
    node.width = width
    node.height = height
    node.apply_style_string(aws_style(icon_name, fill_color))
    return node


def add_group(page, name, x, y, width, height, stroke_color, gr_icon=None, dashed=True):
    group = drawpyo.diagram.Object(page=page, value=name, position=(x, y))
    group.width = width
    group.height = height
    icon_part = f"grIcon=mxgraph.aws4.{gr_icon};" if gr_icon else ""
    style = (
        f"{GROUP_BASE}shape=mxgraph.aws4.group;{icon_part}"
        f"strokeColor={stroke_color};fillColor=none;verticalAlign=top;align=left;spacingLeft=30;"
        f"fontColor={stroke_color};dashed={1 if dashed else 0};"
    )
    group.apply_style_string(style)
    return group


def add_edge(page, source, target, label=None):
    edge = drawpyo.diagram.Edge(page=page, source=source, target=target, label=label)
    edge.waypoints = "orthogonal"
    edge.endArrow = "block"
    edge.startArrow = "none"
    edge.strokeColor = "#545B64"
    return edge


def build_diagram():
    file = drawpyo.File()
    file.file_name = "architecture.drawio"
    file.file_path = OUTPUT_DIR

    page = drawpyo.Page(file=file)
    page.name = "On-premises access to cloud storage"

    app_server = add_node(page, "Application\nserver", 20, 20, "traditional_server", "#232F3D")
    workstation = add_node(page, "User\nworkstation", 20, 180, "traditional_server", "#232F3D")
    backup_server = add_node(page, "Backup\nserver", 20, 340, "traditional_server", "#232F3D")

    local_cache = add_node(page, "Local cache\n(Storage Gateway)", 240, 180, "storage_gateway", "#7AA116")
    vpn = add_node(page, "VPN", 460, 180, "site_to_site_vpn", "#8C4FFF")
    managed_service = add_node(page, "Managed service\n(Storage Gateway)", 680, 180, "storage_gateway", "#7AA116")

    storage_group = add_group(page, "Storage Services", 900, 20, 260, 420, "#7AA116", gr_icon=None, dashed=False)
    s3_bucket = add_node(page, "S3 bucket", 40, 40, "bucket", "#7AA116", parent=storage_group)
    glacier = add_node(page, "S3 Glacier", 40, 160, "glacier", "#7AA116", parent=storage_group)
    ebs_volume = add_node(page, "Elastic\nvolumes (EBS)", 40, 280, "elastic_block_store", "#7AA116", parent=storage_group)

    monitoring_group = add_group(page, "Management and Monitoring", 1220, 20, 220, 420, "#E7157B", gr_icon=None, dashed=False)
    cloudwatch = add_node(page, "CloudWatch", 30, 40, "cloudwatch_2", "#E7157B", parent=monitoring_group)
    notifications = add_node(page, "Notifications\n(SNS)", 30, 160, "sns", "#E7157B", parent=monitoring_group)
    backup_vault = add_node(page, "AWS Backup", 30, 280, "backup", "#7AA116", parent=monitoring_group)

    add_edge(page, app_server, local_cache, label="Standard protocols")
    add_edge(page, workstation, local_cache)
    add_edge(page, backup_server, local_cache)
    add_edge(page, local_cache, vpn)
    add_edge(page, vpn, managed_service)
    add_edge(page, managed_service, storage_group, label="Stores objects")
    add_edge(page, managed_service, monitoring_group, label="Metrics and alarms")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    file.write()
    print(f"Wrote {os.path.join(OUTPUT_DIR, file.file_name)}")


if __name__ == "__main__":
    build_diagram()
